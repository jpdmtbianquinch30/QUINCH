import { Component, inject, OnInit, OnDestroy, signal, computed, ViewChild, ElementRef, AfterViewChecked } from '@angular/core';
import { Router, ActivatedRoute, RouterLink } from '@angular/router';
import { DecimalPipe } from '@angular/common';
import { ChatService, Conversation, Message } from '../../core/services/chat.service';
import { AuthService } from '../../core/services/auth.service';
import { NotificationService } from '../../core/services/notification.service';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-messages',
  standalone: true,
  imports: [DecimalPipe, FormsModule, RouterLink],
  templateUrl: './messages.component.html',
  styleUrl: './messages.component.scss',
})
export class MessagesComponent implements OnInit, OnDestroy, AfterViewChecked {
  chat = inject(ChatService);
  auth = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private notify = inject(NotificationService);

  @ViewChild('messagesContainer') messagesContainer!: ElementRef<HTMLDivElement>;
  @ViewChild('fileInput') fileInputRef!: ElementRef<HTMLInputElement>;

  loading = signal(false);
  selectedConv = signal<Conversation | null>(null);
  newMessage = '';
  isTyping = signal(false);

  // Search
  searchQuery = signal('');

  // Mobile: show chat area instead of list
  mobileShowChat = signal(false);

  // Dropdown menu (more_vert)
  showDropdown = signal(false);

  // Auto-scroll flag
  private shouldScroll = false;

  // ─── Voice Recording ──────────────────────────────────
  isRecording = signal(false);
  recordingDuration = signal(0);
  recordingSending = signal(false);
  private mediaRecorder: MediaRecorder | null = null;
  private audioChunks: Blob[] = [];
  private recordingInterval: any = null;
  private recordingStream: MediaStream | null = null;

  // ─── Audio playback ────────────────────────────────────
  playingAudioId = signal<string | null>(null);
  audioProgress = signal<Record<string, number>>({});
  audioCurrentTime = signal<Record<string, number>>({});
  private audioElements = new Map<string, HTMLAudioElement>();

  // Filtered conversations based on search
  filteredConversations = computed(() => {
    const q = this.searchQuery().toLowerCase().trim();
    const convs = this.chat.conversations();
    if (!q) return convs;
    return convs.filter(c => {
      const name = (c.other_user?.full_name || '').toLowerCase();
      const username = (c.other_user?.username || '').toLowerCase();
      const product = (c.product?.title || '').toLowerCase();
      const lastMsg = (c.last_message?.body || '').toLowerCase();
      return name.includes(q) || username.includes(q) || product.includes(q) || lastMsg.includes(q);
    });
  });

  ngOnInit() {
    this.loading.set(true);
    this.chat.getConversations().subscribe({
      next: () => {
        // Auto-select conversation from query param (e.g. from notification redirect)
        const convId = this.route.snapshot.queryParamMap.get('conversation');
        if (convId) {
          const match = this.chat.conversations().find(c => c.id === convId);
          if (match) {
            this.selectConversation(match);
          }
        }
      },
      complete: () => this.loading.set(false),
    });
  }

  ngOnDestroy() {
    this.stopRecording(true);
    // Clean up audio elements
    this.audioElements.forEach(audio => {
      audio.pause();
      audio.src = '';
    });
    this.audioElements.clear();
  }

  ngAfterViewChecked() {
    if (this.shouldScroll) {
      this.scrollToBottom();
      this.shouldScroll = false;
    }
  }

  selectConversation(conv: Conversation) {
    this.selectedConv.set(conv);
    this.mobileShowChat.set(true);
    this.showDropdown.set(false);
    this.shouldScroll = true;
    // Stop any recording when switching conversations
    if (this.isRecording()) this.stopRecording(true);
    // Stop any playing audio
    this.stopAllAudio();
    this.chat.getConversation(conv.id).subscribe({
      next: () => {
        this.shouldScroll = true;
      }
    });
  }

  sendMessage() {
    const conv = this.selectedConv();
    if (!conv || !this.newMessage.trim()) return;

    this.chat.sendMessage(conv.id, this.newMessage.trim()).subscribe({
      next: () => {
        this.shouldScroll = true;
      },
      error: () => this.notify.error('Erreur envoi message'),
    });
    this.newMessage = '';
  }

  isMe(msg: Message): boolean {
    return msg.sender_id === this.auth.user()?.id;
  }

  // ─── Voice Recording ──────────────────────────────────

  async startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          sampleRate: 44100,
        }
      });
      this.recordingStream = stream;
      this.audioChunks = [];
      this.recordingDuration.set(0);

      // Try webm first, fallback to mp4/ogg
      const mimeType = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : MediaRecorder.isTypeSupported('audio/webm')
          ? 'audio/webm'
          : MediaRecorder.isTypeSupported('audio/mp4')
            ? 'audio/mp4'
            : 'audio/ogg';

      this.mediaRecorder = new MediaRecorder(stream, { mimeType });

      this.mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) {
          this.audioChunks.push(e.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        // Handled in sendVoiceMessage / cancelRecording
      };

      this.mediaRecorder.start(100); // collect data every 100ms
      this.isRecording.set(true);

      // Timer
      this.recordingInterval = setInterval(() => {
        this.recordingDuration.update(d => d + 0.1);
      }, 100);

    } catch (err: any) {
      if (err.name === 'NotAllowedError') {
        this.notify.error('Accès au microphone refusé. Autorisez le micro dans les paramètres.');
      } else if (err.name === 'NotFoundError') {
        this.notify.error('Aucun microphone détecté.');
      } else {
        this.notify.error('Impossible d\'accéder au microphone.');
      }
    }
  }

  sendVoiceMessage() {
    if (!this.mediaRecorder || this.mediaRecorder.state === 'inactive') return;
    const conv = this.selectedConv();
    if (!conv) return;

    const duration = this.recordingDuration();
    if (duration < 0.5) {
      this.notify.warning('Message vocal trop court.');
      this.stopRecording(true);
      return;
    }

    this.recordingSending.set(true);

    this.mediaRecorder.onstop = () => {
      const audioBlob = new Blob(this.audioChunks, { type: this.mediaRecorder?.mimeType || 'audio/webm' });
      this.cleanupRecording();

      this.chat.sendAudioMessage(conv.id, audioBlob, duration).subscribe({
        next: () => {
          this.shouldScroll = true;
          this.recordingSending.set(false);
          this.notify.success('Message vocal envoyé');
        },
        error: () => {
          this.recordingSending.set(false);
          this.notify.error('Erreur envoi du message vocal');
        }
      });
    };

    this.mediaRecorder.stop();
  }

  cancelRecording() {
    this.stopRecording(true);
  }

  private stopRecording(cleanup: boolean) {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.onstop = () => {}; // prevent sending
      this.mediaRecorder.stop();
    }
    if (cleanup) {
      this.cleanupRecording();
    }
  }

  private cleanupRecording() {
    if (this.recordingInterval) {
      clearInterval(this.recordingInterval);
      this.recordingInterval = null;
    }
    if (this.recordingStream) {
      this.recordingStream.getTracks().forEach(t => t.stop());
      this.recordingStream = null;
    }
    this.mediaRecorder = null;
    this.audioChunks = [];
    this.isRecording.set(false);
    this.recordingDuration.set(0);
  }

  formatRecordingTime(): string {
    const secs = Math.floor(this.recordingDuration());
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
  }

  // ─── Audio Playback ───────────────────────────────────

  toggleAudioPlay(msg: Message) {
    const audioUrl = msg.metadata?.audio_url;
    if (!audioUrl) return;

    const currentlyPlaying = this.playingAudioId();

    // If this message is playing, pause it
    if (currentlyPlaying === msg.id) {
      const audio = this.audioElements.get(msg.id);
      if (audio) {
        audio.pause();
      }
      this.playingAudioId.set(null);
      return;
    }

    // Stop any other playing audio
    this.stopAllAudio();

    // Get or create audio element
    let audio = this.audioElements.get(msg.id);
    if (!audio) {
      audio = new Audio(audioUrl);
      audio.preload = 'metadata';

      audio.ontimeupdate = () => {
        if (audio!.duration) {
          const pct = (audio!.currentTime / audio!.duration) * 100;
          this.audioProgress.update(p => ({ ...p, [msg.id]: pct }));
          this.audioCurrentTime.update(t => ({ ...t, [msg.id]: audio!.currentTime }));
        }
      };

      audio.onended = () => {
        this.playingAudioId.set(null);
        this.audioProgress.update(p => ({ ...p, [msg.id]: 0 }));
        this.audioCurrentTime.update(t => ({ ...t, [msg.id]: 0 }));
      };

      audio.onerror = () => {
        this.playingAudioId.set(null);
        this.notify.error('Impossible de lire le message vocal');
      };

      this.audioElements.set(msg.id, audio);
    }

    audio.play().then(() => {
      this.playingAudioId.set(msg.id);
    }).catch(() => {
      this.notify.error('Impossible de lire le message vocal');
    });
  }

  seekAudio(msg: Message, event: MouseEvent) {
    const audio = this.audioElements.get(msg.id);
    if (!audio || !audio.duration) return;
    const bar = event.currentTarget as HTMLElement;
    const rect = bar.getBoundingClientRect();
    const pct = (event.clientX - rect.left) / rect.width;
    audio.currentTime = pct * audio.duration;
    this.audioProgress.update(p => ({ ...p, [msg.id]: pct * 100 }));
  }

  getAudioProgress(msgId: string): number {
    return this.audioProgress()[msgId] || 0;
  }

  getAudioCurrentTime(msgId: string): number {
    return this.audioCurrentTime()[msgId] || 0;
  }

  isAudioPlaying(msgId: string): boolean {
    return this.playingAudioId() === msgId;
  }

  formatAudioDuration(seconds: number | undefined): string {
    if (!seconds || seconds <= 0) return '0:00';
    const s = Math.round(seconds);
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m}:${sec.toString().padStart(2, '0')}`;
  }

  private stopAllAudio() {
    this.audioElements.forEach(audio => audio.pause());
    this.playingAudioId.set(null);
  }

  // ─── Button handlers ─────────────────────────────────

  goBack() {
    this.mobileShowChat.set(false);
    this.selectedConv.set(null);
    this.showDropdown.set(false);
    if (this.isRecording()) this.stopRecording(true);
    this.stopAllAudio();
    this.chat.getConversations().subscribe();
  }

  viewProfile() {
    const username = this.selectedConv()?.other_user?.username;
    if (username) {
      this.router.navigate(['/seller', username]);
    } else {
      this.notify.info('Profil non disponible');
    }
  }

  onCall() {
    this.notify.info('Les appels seront bientôt disponibles.');
  }

  toggleDropdown() {
    this.showDropdown.update(v => !v);
  }

  closeDropdown() {
    this.showDropdown.set(false);
  }

  onViewProfile() {
    this.closeDropdown();
    this.viewProfile();
  }

  onMarkAllRead() {
    this.closeDropdown();
    const conv = this.selectedConv();
    if (conv) {
      this.chat.markConversationRead(conv.id);
      this.notify.success('Conversation marquée comme lue');
    }
  }

  onDeleteConversation() {
    this.closeDropdown();
    const conv = this.selectedConv();
    if (!conv) return;
    if (confirm('Supprimer cette conversation ? Cette action est irréversible.')) {
      this.chat.deleteConversation(conv.id).subscribe({
        next: () => {
          this.selectedConv.set(null);
          this.mobileShowChat.set(false);
          this.notify.success('Conversation supprimée');
        },
        error: () => this.notify.error('Erreur lors de la suppression'),
      });
    }
  }

  onMuteConversation() {
    this.closeDropdown();
    this.notify.info('Notifications de cette conversation désactivées.');
  }

  // ─── File Attachment ─────────────────────────────────
  fileSending = signal(false);
  showAttachMenu = signal(false);

  attachOptions = [
    { id: 'image', label: 'Photos & Images', icon: 'image', accept: 'image/jpeg,image/png,image/gif,image/webp', color: '#6366f1' },
    { id: 'document', label: 'Documents', icon: 'description', accept: '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.csv', color: '#f59e0b' },
    { id: 'video', label: 'Videos', icon: 'videocam', accept: 'video/mp4,video/webm,video/quicktime', color: '#ef4444' },
    { id: 'audio', label: 'Audio', icon: 'headphones', accept: 'audio/mpeg,audio/wav,audio/ogg,audio/webm,.mp3', color: '#22c55e' },
    { id: 'other', label: 'Autres fichiers', icon: 'folder', accept: '*/*', color: '#8b5cf6' },
  ];

  toggleAttachMenu() {
    this.showAttachMenu.update(v => !v);
  }

  closeAttachMenu() {
    this.showAttachMenu.set(false);
  }

  onAttachFile() {
    this.toggleAttachMenu();
  }

  selectAttachType(accept: string) {
    this.showAttachMenu.set(false);
    const input = this.fileInputRef?.nativeElement;
    if (!input) return;
    input.accept = accept;
    input.click();
  }

  onFileSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    if (!input.files || !input.files[0]) return;
    const file = input.files[0];
    const conv = this.selectedConv();
    if (!conv) return;

    // Max 20 MB
    if (file.size > 20 * 1024 * 1024) {
      this.notify.error('Le fichier ne doit pas depasser 20 Mo.');
      input.value = '';
      return;
    }

    this.fileSending.set(true);
    this.chat.sendFile(conv.id, file).subscribe({
      next: () => {
        this.shouldScroll = true;
        this.fileSending.set(false);
        this.notify.success('Fichier envoye !');
      },
      error: (err: any) => {
        this.fileSending.set(false);
        this.notify.error(err?.error?.message || 'Erreur envoi du fichier');
      }
    });
    input.value = '';
  }

  isImageMessage(msg: Message): boolean {
    return msg.type === 'image' || (msg.metadata?.mime_type?.startsWith('image/') ?? false);
  }

  isFileMessage(msg: Message): boolean {
    return msg.type === 'file';
  }

  getFileUrl(msg: Message): string {
    return msg.metadata?.file_url || '';
  }

  getFileName(msg: Message): string {
    return msg.metadata?.file_name || 'Fichier';
  }

  getFileSize(msg: Message): string {
    const bytes = msg.metadata?.file_size;
    if (!bytes) return '';
    if (bytes < 1024) return bytes + ' o';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' Ko';
    return (bytes / (1024 * 1024)).toFixed(1) + ' Mo';
  }

  getFileExtension(msg: Message): string {
    return (msg.metadata?.extension || '').toUpperCase();
  }

  onNewConversation() {
    this.notify.info('Contactez un vendeur depuis sa page profil pour démarrer une conversation.');
  }

  isQuoteMessage(msg: Message): boolean {
    return msg.body?.startsWith('[Demande de devis]') ?? false;
  }

  getQuoteBody(msg: Message): string {
    return (msg.body || '').replace('[Demande de devis] ', '').replace('[Demande de devis]', '');
  }

  // ─── Helpers ──────────────────────────────────────────

  getLastMessagePreview(conv: Conversation): string {
    const msg = conv.last_message;
    if (!msg) return 'Aucun message';
    if (msg.type === 'system') return '📢 ' + (msg.body || '').substring(0, 40);
    if (msg.type === 'image') return '📷 Image';
    if (msg.type === 'file') return '📎 ' + (msg.metadata?.file_name || 'Fichier');
    if (msg.type === 'offer') return '💰 Offre';
    if (msg.type === 'audio') return '🎤 Message vocal';
    const body = msg.body || '';
    return body.length > 50 ? body.substring(0, 50) + '…' : body;
  }

  isLastMessageMine(conv: Conversation): boolean {
    return conv.last_message?.sender_id === this.auth.user()?.id;
  }

  isLastMessageRead(conv: Conversation): boolean {
    return conv.last_message?.is_read ?? false;
  }

  formatTime(dateStr: string): string {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    const now = new Date();
    const diff = now.getTime() - d.getTime();
    if (diff < 60000) return "A l'instant";
    if (diff < 3600000) return Math.floor(diff / 60000) + ' min';
    if (diff < 86400000) return Math.floor(diff / 3600000) + ' h';
    if (diff < 604800000) {
      const days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
      return days[d.getDay()];
    }
    return d.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
  }

  private scrollToBottom() {
    try {
      const el = this.messagesContainer?.nativeElement;
      if (el) {
        el.scrollTop = el.scrollHeight;
      }
    } catch (_) {}
  }
}
