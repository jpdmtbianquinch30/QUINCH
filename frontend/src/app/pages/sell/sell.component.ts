import { Component, inject, signal, OnInit, OnDestroy, ViewChild, ElementRef, HostListener } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { DecimalPipe } from '@angular/common';
import { Router } from '@angular/router';
import { ProductService } from '../../core/services/product.service';
import { NotificationService } from '../../core/services/notification.service';
import { Category } from '../../core/models/product.model';

@Component({
  selector: 'app-sell',
  standalone: true,
  imports: [FormsModule, DecimalPipe],
  templateUrl: './sell.component.html',
  styleUrl: './sell.component.scss',
})
export class SellComponent implements OnInit, OnDestroy {
  @ViewChild('cameraPreview') cameraPreviewRef!: ElementRef<HTMLVideoElement>;
  @ViewChild('editorVideo') editorVideoRef!: ElementRef<HTMLVideoElement>;
  @ViewChild('videoWrap') videoWrapRef!: ElementRef<HTMLDivElement>;

  private productService = inject(ProductService);
  private router = inject(Router);
  private notify = inject(NotificationService);

  categories = signal<Category[]>([]);
  loading = signal(false);
  videoFile: File | null = null;
  videoId = signal('');
  videoPreview = signal('');
  videoResolution = signal('');

  // Poster image (required main product image)
  posterFile: File | null = null;
  posterPreview = signal('');

  imageFiles: File[] = [];
  imagePreviews = signal<string[]>([]);
  publishType = signal<'product' | 'service'>('product');

  // ─── Camera ──────────────────────────────
  cameraMode = signal(false);
  recording = signal(false);
  cameraStream: MediaStream | null = null;
  private mediaRecorder: MediaRecorder | null = null;
  private recordedChunks: Blob[] = [];
  recordingTime = signal(0);
  private recordingTimer: any = null;
  cameraFacing = signal<'user' | 'environment'>('environment');

  // Quality
  videoQuality = signal<'4k' | '1080p' | '720p'>('1080p');
  qualityOptions = [
    { value: '4k' as const, label: '4K Ultra HD', w: 3840, h: 2160 },
    { value: '1080p' as const, label: 'Full HD 1080p', w: 1920, h: 1080 },
    { value: '720p' as const, label: 'HD 720p', w: 1280, h: 720 },
  ];

  // ═══════════════════════════════════════════
  // VIDEO EDITOR
  // ═══════════════════════════════════════════
  showVideoEditor = signal(false);
  videoEdited = signal(false);
  videoEditorTab = signal<'filters' | 'text' | 'adjust' | 'settings'>('filters');
  videoDuration = signal(0);
  videoCurrentTime = signal(0);
  editorPlaying = signal(true);

  // Filters
  activeVideoFilter = signal('none');
  videoFilters = [
    { id: 'none', name: 'Original', css: '' },
    { id: 'bright', name: 'Lumineux', css: 'brightness(1.2) contrast(1.05)' },
    { id: 'warm', name: 'Chaud', css: 'saturate(1.3) sepia(0.15) brightness(1.05)' },
    { id: 'cool', name: 'Froid', css: 'saturate(0.9) hue-rotate(15deg) brightness(1.05)' },
    { id: 'vivid', name: 'Vivide', css: 'saturate(1.5) contrast(1.1)' },
    { id: 'bw', name: 'N&B', css: 'grayscale(1) contrast(1.1)' },
    { id: 'vintage', name: 'Vintage', css: 'sepia(0.35) contrast(0.9) brightness(1.1)' },
    { id: 'drama', name: 'Drama', css: 'contrast(1.3) brightness(0.95) saturate(1.2)' },
    { id: 'cinematic', name: 'Cinema', css: 'contrast(1.15) saturate(0.85) brightness(0.95) sepia(0.1)' },
    { id: 'glow', name: 'Glow', css: 'brightness(1.15) contrast(0.9) saturate(1.2)' },
  ];

  // Adjustments — all live
  videoBrightness = signal(100);
  videoContrast = signal(100);
  videoSaturation = signal(100);
  videoHue = signal(0);
  videoBlur = signal(0);
  videoVignette = signal(0);
  videoRotation = signal(0);
  videoSpeed = signal(1);
  videoFlipH = signal(false);
  videoFlipV = signal(false);
  videoZoom = signal(100);

  // Aspect ratio / size
  videoAspectRatio = signal('9/16');
  aspectOptions = [
    { value: '9/16', label: '9:16', icon: 'smartphone' },
    { value: '16/9', label: '16:9', icon: 'tv' },
    { value: '1/1', label: '1:1', icon: 'crop_square' },
    { value: '4/5', label: '4:5', icon: 'crop_portrait' },
    { value: 'free', label: 'Libre', icon: 'crop_free' },
  ];

  // Text overlays — free positioned
  textOverlays = signal<TextOverlay[]>([]);
  selectedTextIdx = signal<number | null>(null);
  newTextContent = '';
  newTextColor = '#ffffff';
  newTextSize = 28;
  newTextFont = 'Sans-serif';
  newTextBg = signal(true);
  newTextBgOpacity = signal(55);
  newTextBgColor = '#000000';
  newTextStroke = signal(false);
  newTextShadow = signal(true);
  newTextRotation = signal(0);
  newTextBold = signal(true);

  textFonts = [
    { name: 'Sans-serif', family: 'Inter, sans-serif' },
    { name: 'Serif', family: 'Georgia, serif' },
    { name: 'Mono', family: 'monospace' },
    { name: 'Cursive', family: 'cursive' },
    { name: 'Impact', family: 'Impact, sans-serif' },
  ];

  textColors = [
    '#ffffff', '#000000', '#ef4444', '#f59e0b', '#22c55e',
    '#3b82f6', '#8b5cf6', '#ec4899', '#06b6d4', '#f97316',
  ];

  // Drag state
  private dragging = false;
  private dragIdx = -1;
  private dragStartX = 0;
  private dragStartY = 0;
  private dragOrigX = 0;
  private dragOrigY = 0;

  // ─── Photo Filters ─────────────────────────────────
  activeFilter = signal('none');
  photoFilters = [
    { id: 'none', name: 'Original', css: '' },
    { id: 'bright', name: 'Lumineux', css: 'brightness(1.2) contrast(1.05)' },
    { id: 'warm', name: 'Chaud', css: 'saturate(1.3) sepia(0.15) brightness(1.05)' },
    { id: 'cool', name: 'Froid', css: 'saturate(0.9) hue-rotate(15deg) brightness(1.05)' },
    { id: 'vivid', name: 'Vivide', css: 'saturate(1.5) contrast(1.1)' },
    { id: 'bw', name: 'N&B', css: 'grayscale(1) contrast(1.1)' },
    { id: 'vintage', name: 'Vintage', css: 'sepia(0.35) contrast(0.9) brightness(1.1)' },
    { id: 'drama', name: 'Drama', css: 'contrast(1.3) brightness(0.95) saturate(1.2)' },
  ];
  editingImageIdx = signal<number | null>(null);

  form = {
    title: '', description: '', category_id: '', price: 0, stock_quantity: 1, condition: 'new',
    is_negotiable: true, type: 'product' as 'product' | 'service',
    // Service-specific fields
    service_type: 'in_person' as 'online' | 'in_person' | 'both',
    availability: 'weekdays' as string,
    duration: '',
    service_area: '',
    experience_years: '' as string | number,
    return_policy: 'Retour sous 7 jours', warranty: false,
  };

  // Payment methods the seller accepts
  availablePaymentMethods = [
    { id: 'orange_money', name: 'Orange Money', icon: 'phone_android', color: '#ff6600' },
    { id: 'wave', name: 'Wave', icon: 'waves', color: '#1dc3e4' },
    { id: 'free_money', name: 'Free Money', icon: 'smartphone', color: '#00a651' },
    { id: 'cash_delivery', name: 'Paiement a la livraison', icon: 'local_shipping', color: '#f59e0b' },
    { id: 'cash_hand', name: 'Especes (en main propre)', icon: 'payments', color: '#22c55e' },
    { id: 'bank_transfer', name: 'Virement bancaire', icon: 'account_balance', color: '#6366f1' },
  ];
  selectedPaymentMethods = signal<string[]>([]);

  // Delivery options: 'fixed' = seller sets a fee the buyer pays, 'contact' = buyer contacts seller
  deliveryOption = signal<'fixed' | 'contact'>('contact');
  deliveryFee = signal(0);

  currentStep = signal(1);

  productCategories = [
    { emoji: '📱', name: 'Electronique', id: 'electronics' },
    { emoji: '👕', name: 'Mode & Accessoires', id: 'fashion' },
    { emoji: '🏠', name: 'Maison & Deco', id: 'home' },
    { emoji: '🚗', name: 'Vehicules', id: 'vehicles' },
    { emoji: '🛋️', name: 'Meubles', id: 'furniture' },
    { emoji: '📚', name: 'Livres & Education', id: 'books' },
    { emoji: '🎵', name: 'Instruments de musique', id: 'music' },
  ];

  serviceCategories = [
    { emoji: '💻', name: 'Developpement & Tech', id: 'digital', desc: 'Sites web, apps, IT' },
    { emoji: '🎨', name: 'Design & Graphisme', id: 'design', desc: 'Logos, flyers, UI/UX' },
    { emoji: '📸', name: 'Photo & Videographie', id: 'photo_video', desc: 'Shootings, montage' },
    { emoji: '👨‍🏫', name: 'Cours & Formations', id: 'courses', desc: 'Tutorat, coaching' },
    { emoji: '🔧', name: 'Reparation & Maintenance', id: 'repair', desc: 'Plomberie, electricite' },
    { emoji: '🏠', name: 'Services a Domicile', id: 'home_services', desc: 'Menage, cuisine' },
    { emoji: '🎉', name: 'Evenementiel', id: 'events', desc: 'DJ, decoration, traiteur' },
    { emoji: '🚚', name: 'Transport & Livraison', id: 'transport', desc: 'Demenagement, courses' },
    { emoji: '💇', name: 'Beaute & Coiffure', id: 'beauty', desc: 'Coiffure, maquillage' },
    { emoji: '🏥', name: 'Sante & Bien-etre', id: 'health', desc: 'Massage, coaching sportif' },
    { emoji: '📝', name: 'Redaction & Traduction', id: 'writing', desc: 'Articles, traductions' },
    { emoji: '📣', name: 'Marketing & Publicite', id: 'marketing', desc: 'Social media, SEO' },
    { emoji: '⚖️', name: 'Conseil & Juridique', id: 'consulting', desc: 'Comptabilite, droit' },
    { emoji: '🎵', name: 'Musique & Audio', id: 'music', desc: 'Production, cours musique' },
  ];

  // Service-specific options
  serviceTypes: { id: 'online' | 'in_person' | 'both'; label: string; icon: string; desc: string }[] = [
    { id: 'in_person', label: 'Sur place', icon: 'person_pin_circle', desc: 'Je me deplace ou le client vient' },
    { id: 'online', label: 'En ligne', icon: 'language', desc: 'Service a distance (visio, telephone)' },
    { id: 'both', label: 'Les deux', icon: 'swap_horiz', desc: 'Sur place et en ligne' },
  ];

  availabilityOptions = [
    { id: 'everyday', label: 'Tous les jours', icon: 'event_available' },
    { id: 'weekdays', label: 'Lundi - Vendredi', icon: 'work' },
    { id: 'weekends', label: 'Weekends uniquement', icon: 'weekend' },
    { id: 'appointment', label: 'Sur rendez-vous', icon: 'schedule' },
    { id: 'custom', label: 'Horaires personnalises', icon: 'tune' },
  ];

  durationOptions = [
    { id: '30min', label: '30 minutes' },
    { id: '1h', label: '1 heure' },
    { id: '2h', label: '2 heures' },
    { id: 'half_day', label: 'Demi-journee' },
    { id: 'full_day', label: 'Journee complete' },
    { id: 'multi_day', label: 'Plusieurs jours' },
    { id: 'project', label: 'Sur devis / projet' },
  ];

  // Payment methods filtered for services (no cash_delivery)
  servicePaymentMethods = [
    { id: 'orange_money', name: 'Orange Money', icon: 'phone_android', color: '#ff6600' },
    { id: 'wave', name: 'Wave', icon: 'waves', color: '#1dc3e4' },
    { id: 'free_money', name: 'Free Money', icon: 'smartphone', color: '#00a651' },
    { id: 'cash_hand', name: 'Especes (en main propre)', icon: 'payments', color: '#22c55e' },
    { id: 'bank_transfer', name: 'Virement bancaire', icon: 'account_balance', color: '#6366f1' },
    { id: 'online_payment', name: 'Paiement en ligne', icon: 'credit_card', color: '#8b5cf6' },
  ];

  /** Price type for services */
  servicePriceType = signal<'fixed' | 'starting' | 'hourly' | 'quote'>('fixed');
  servicePriceTypes: { id: 'fixed' | 'starting' | 'hourly' | 'quote'; label: string; icon: string; desc: string }[] = [
    { id: 'fixed', label: 'Prix fixe', icon: 'payments', desc: 'Tarif unique pour la prestation' },
    { id: 'starting', label: 'A partir de', icon: 'trending_up', desc: 'Prix minimum, ajustable' },
    { id: 'hourly', label: 'Par heure', icon: 'schedule', desc: 'Tarif horaire' },
    { id: 'quote', label: 'Sur devis', icon: 'request_quote', desc: 'Prix sur demande' },
  ];

  ngOnInit() {
    this.productService.getCategories().subscribe({
      next: (res) => this.categories.set(res.categories),
    });
  }

  ngOnDestroy() {
    this.stopCamera();
    if (this.recordingTimer) clearInterval(this.recordingTimer);
  }

  setType(type: 'product' | 'service') {
    this.publishType.set(type);
    this.form.type = type;
    this.form.category_id = '';
    this.selectedPaymentMethods.set([]);
  }

  nextStep() {
    // Validate poster before going to step 2
    if (this.currentStep() === 1 && !this.posterFile) {
      this.notify.error('L\'image d\'affiche est obligatoire. Ajoutez une photo de votre ' + (this.publishType() === 'service' ? 'service.' : 'produit.'));
      return;
    }
    if (this.currentStep() < 3) this.currentStep.update(s => s + 1);
  }

  /** Get the right payment methods list based on publish type */
  getPaymentMethods() {
    return this.publishType() === 'service' ? this.servicePaymentMethods : this.availablePaymentMethods;
  }

  /** Get formatted price label for services */
  getServicePriceLabel(): string {
    const t = this.servicePriceType();
    if (t === 'quote') return 'Sur devis';
    if (t === 'hourly') return `${this.form.price || 0} F CFA / heure`;
    if (t === 'starting') return `A partir de ${this.form.price || 0} F CFA`;
    return `${this.form.price || 0} F CFA`;
  }
  prevStep() { if (this.currentStep() > 1) this.currentStep.update(s => s - 1); }

  // ═══════ POSTER IMAGE (required) ═══════
  onPosterSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files[0]) {
      const file = input.files[0];
      if (file.size > 5 * 1024 * 1024) {
        this.notify.error('L\'image ne doit pas depasser 5 Mo.');
        return;
      }
      this.posterFile = file;
      const reader = new FileReader();
      reader.onload = () => this.posterPreview.set(reader.result as string);
      reader.readAsDataURL(file);
    }
  }

  removePoster() {
    this.posterFile = null;
    this.posterPreview.set('');
  }

  // ═══════ VIDEO UPLOAD ═══════
  onVideoSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files[0]) {
      this.videoFile = input.files[0];
      if (this.videoFile.size > 200 * 1024 * 1024) {
        this.notify.error('Video trop lourde (max 200 Mo)');
        this.videoFile = null;
        return;
      }
      this.videoPreview.set(URL.createObjectURL(this.videoFile));
      this.detectVideoResolution(this.videoFile);
      this.openVideoEditor();
    }
  }

  private detectVideoResolution(file: File) {
    const video = document.createElement('video');
    video.preload = 'metadata';
    video.onloadedmetadata = () => {
      const w = video.videoWidth, h = video.videoHeight, m = Math.max(w, h);
      this.videoResolution.set(m >= 3840 ? '4K' : m >= 1920 ? '1080p' : m >= 1280 ? '720p' : m >= 854 ? '480p' : 'SD');
      this.videoDuration.set(Math.floor(video.duration));
      URL.revokeObjectURL(video.src);
    };
    video.src = URL.createObjectURL(file);
  }

  uploadVideo(source: 'upload' | 'camera') {
    if (!this.videoFile) return;
    this.loading.set(true);
    const fd = new FormData();
    fd.append('video', this.videoFile);
    fd.append('source', source);
    const v = document.createElement('video');
    v.preload = 'metadata';
    v.onloadedmetadata = () => { fd.append('width', String(v.videoWidth)); fd.append('height', String(v.videoHeight)); URL.revokeObjectURL(v.src); this.doUpload(fd); };
    v.onerror = () => this.doUpload(fd);
    v.src = URL.createObjectURL(this.videoFile);
  }

  private doUpload(fd: FormData) {
    this.productService.uploadVideoRaw(fd).subscribe({
      next: (res: any) => { this.videoId.set(res.video.id); this.loading.set(false); this.notify.success(`Video uploadee! ${res.video.quality_label ? '(' + res.video.quality_label + ')' : ''}`); },
      error: (err) => { this.notify.error(err.error?.message || 'Erreur upload video'); this.loading.set(false); },
    });
  }

  // ═══════ VIDEO EDITOR ═══════
  openVideoEditor() {
    this.showVideoEditor.set(true);
    this.videoEditorTab.set('filters');
    this.activeVideoFilter.set('none');
    this.textOverlays.set([]);
    this.resetAdjustments();
    this.editorPlaying.set(true);
    setTimeout(() => { this.editorVideoRef?.nativeElement?.play().catch(() => {}); }, 200);
  }

  closeVideoEditor() { this.showVideoEditor.set(false); }

  confirmVideoEdit() {
    // Check if any edits were actually made
    const hasEdits = this.activeVideoFilter() !== 'none'
      || this.videoBrightness() !== 100 || this.videoContrast() !== 100
      || this.videoSaturation() !== 100 || this.videoHue() !== 0
      || this.videoBlur() !== 0 || this.videoVignette() !== 0
      || this.videoRotation() !== 0 || this.videoFlipH() || this.videoFlipV()
      || this.videoZoom() !== 100 || this.textOverlays().length > 0;
    this.videoEdited.set(hasEdits);
    this.showVideoEditor.set(false);
    this.uploadVideo(this.cameraMode() ? 'camera' : 'upload');
  }


  toggleEditorPlay() {
    const v = this.editorVideoRef?.nativeElement;
    if (!v) return;
    if (v.paused) { v.play(); this.editorPlaying.set(true); }
    else { v.pause(); this.editorPlaying.set(false); }
  }

  // Live combined CSS filter
  getVideoEditorFilterCss(): string {
    const f = this.videoFilters.find(x => x.id === this.activeVideoFilter());
    const parts: string[] = [];
    if (f?.css) parts.push(f.css);
    parts.push(`brightness(${this.videoBrightness() / 100})`);
    parts.push(`contrast(${this.videoContrast() / 100})`);
    parts.push(`saturate(${this.videoSaturation() / 100})`);
    if (this.videoHue()) parts.push(`hue-rotate(${this.videoHue()}deg)`);
    if (this.videoBlur()) parts.push(`blur(${this.videoBlur()}px)`);
    return parts.join(' ');
  }

  getVideoTransform(): string {
    const parts: string[] = [];
    parts.push(`scale(${this.videoZoom() / 100})`);
    if (this.videoRotation()) parts.push(`rotate(${this.videoRotation()}deg)`);
    if (this.videoFlipH()) parts.push('scaleX(-1)');
    if (this.videoFlipV()) parts.push('scaleY(-1)');
    return parts.join(' ');
  }

  getVideoFilterCss(filterId: string): string {
    return this.videoFilters.find(f => f.id === filterId)?.css || '';
  }

  onEditorVideoTimeUpdate() {
    const v = this.editorVideoRef?.nativeElement;
    if (v) this.videoCurrentTime.set(v.currentTime);
  }

  onEditorVideoLoaded() {
    const v = this.editorVideoRef?.nativeElement;
    if (v) {
      this.videoDuration.set(v.duration);
      v.playbackRate = this.videoSpeed();
    }
  }

  seekVideo(event: Event) {
    const v = this.editorVideoRef?.nativeElement;
    if (v) v.currentTime = Number((event.target as HTMLInputElement).value);
  }

  setVideoSpeed(speed: number) {
    this.videoSpeed.set(speed);
    const v = this.editorVideoRef?.nativeElement;
    if (v) v.playbackRate = speed;
  }

  resetAdjustments() {
    this.videoBrightness.set(100); this.videoContrast.set(100); this.videoSaturation.set(100);
    this.videoHue.set(0); this.videoBlur.set(0); this.videoVignette.set(0);
    this.videoRotation.set(0); this.videoSpeed.set(1); this.videoFlipH.set(false);
    this.videoFlipV.set(false); this.videoZoom.set(100); this.videoAspectRatio.set('9/16');
    const v = this.editorVideoRef?.nativeElement;
    if (v) v.playbackRate = 1;
  }

  rotateVideo(deg: number) { this.videoRotation.update(r => (r + deg) % 360); }
  toggleFlipH() { this.videoFlipH.update(v => !v); }
  toggleFlipV() { this.videoFlipV.update(v => !v); }

  // ═══════ TEXT OVERLAYS (DRAGGABLE) ═══════
  addTextOverlay() {
    if (!this.newTextContent.trim()) return;
    const overlay: TextOverlay = {
      text: this.newTextContent.trim(),
      color: this.newTextColor,
      size: this.newTextSize,
      x: 50, y: 50,
      font: this.newTextFont,
      hasBg: this.newTextBg(),
      bgOpacity: this.newTextBgOpacity(),
      bgColor: this.newTextBgColor,
      hasStroke: this.newTextStroke(),
      hasShadow: this.newTextShadow(),
      rotation: this.newTextRotation(),
      bold: this.newTextBold(),
    };
    this.textOverlays.update(list => [...list, overlay]);
    this.selectedTextIdx.set(this.textOverlays().length - 1);
    this.newTextContent = '';
  }

  selectText(idx: number, event: Event) {
    event.stopPropagation();
    this.selectedTextIdx.set(idx);
  }

  deselectText() {
    this.selectedTextIdx.set(null);
  }

  removeTextOverlay(idx: number) {
    this.textOverlays.update(list => list.filter((_, i) => i !== idx));
    if (this.selectedTextIdx() === idx) this.selectedTextIdx.set(null);
  }

  duplicateText(idx: number) {
    const t = { ...this.textOverlays()[idx], x: this.textOverlays()[idx].x + 5, y: this.textOverlays()[idx].y + 5 };
    this.textOverlays.update(list => [...list, t]);
    this.selectedTextIdx.set(this.textOverlays().length - 1);
  }

  updateSelectedText(field: keyof TextOverlay, value: any) {
    const idx = this.selectedTextIdx();
    if (idx === null) return;
    this.textOverlays.update(list => list.map((t, i) => i === idx ? { ...t, [field]: value } : t));
  }

  getTextStyle(t: TextOverlay): Record<string, string> {
    const style: Record<string, string> = {
      left: `${t.x}%`, top: `${t.y}%`,
      color: t.color, 'font-size': `${t.size}px`,
      'font-family': this.textFonts.find(f => f.name === t.font)?.family || t.font,
      transform: `translate(-50%, -50%) rotate(${t.rotation || 0}deg)`,
      'font-weight': t.bold ? '800' : '400',
    };
    if (t.hasBg) {
      const c = t.bgColor || '#000000';
      const r = parseInt(c.slice(1, 3), 16), g = parseInt(c.slice(3, 5), 16), b = parseInt(c.slice(5, 7), 16);
      style['background'] = `rgba(${r},${g},${b},${(t.bgOpacity || 55) / 100})`;
    }
    if (t.hasStroke) style['-webkit-text-stroke'] = `1px ${t.color === '#000000' ? '#ffffff' : '#000000'}`;
    if (t.hasShadow) style['text-shadow'] = '0 2px 8px rgba(0,0,0,0.7)';
    return style;
  }

  // Drag start
  onTextDragStart(event: MouseEvent | TouchEvent, idx: number) {
    event.preventDefault();
    event.stopPropagation();
    this.dragging = true;
    this.dragIdx = idx;
    this.selectedTextIdx.set(idx);
    const pos = this.getEventPos(event);
    this.dragStartX = pos.x;
    this.dragStartY = pos.y;
    this.dragOrigX = this.textOverlays()[idx].x;
    this.dragOrigY = this.textOverlays()[idx].y;
  }

  @HostListener('document:mousemove', ['$event'])
  @HostListener('document:touchmove', ['$event'])
  onDragMove(event: MouseEvent | TouchEvent) {
    if (!this.dragging) return;
    event.preventDefault();
    const wrap = this.videoWrapRef?.nativeElement;
    if (!wrap) return;
    const rect = wrap.getBoundingClientRect();
    const pos = this.getEventPos(event);
    const dx = ((pos.x - this.dragStartX) / rect.width) * 100;
    const dy = ((pos.y - this.dragStartY) / rect.height) * 100;
    const newX = Math.max(5, Math.min(95, this.dragOrigX + dx));
    const newY = Math.max(5, Math.min(95, this.dragOrigY + dy));
    this.textOverlays.update(list => list.map((t, i) => i === this.dragIdx ? { ...t, x: newX, y: newY } : t));
  }

  @HostListener('document:mouseup')
  @HostListener('document:touchend')
  onDragEnd() {
    this.dragging = false;
    this.dragIdx = -1;
  }

  private getEventPos(e: MouseEvent | TouchEvent): { x: number; y: number } {
    if (e instanceof TouchEvent && e.touches.length) return { x: e.touches[0].clientX, y: e.touches[0].clientY };
    if (e instanceof MouseEvent) return { x: e.clientX, y: e.clientY };
    return { x: 0, y: 0 };
  }

  // ═══════ CAMERA ═══════
  async openCamera() {
    try {
      const q = this.qualityOptions.find(o => o.value === this.videoQuality())!;
      this.cameraStream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: this.cameraFacing(), width: { ideal: q.w }, height: { ideal: q.h } }, audio: true,
      });
      this.cameraMode.set(true);
      setTimeout(() => { if (this.cameraPreviewRef) this.cameraPreviewRef.nativeElement.srcObject = this.cameraStream; }, 100);
    } catch { this.notify.error('Impossible d\'acceder a la camera.'); }
  }

  flipCamera() { this.cameraFacing.update(f => f === 'user' ? 'environment' : 'user'); this.stopCamera(); this.openCamera(); }

  startRecording() {
    if (!this.cameraStream) return;
    this.recordedChunks = [];
    let mime = 'video/webm;codecs=vp9,opus';
    if (!MediaRecorder.isTypeSupported(mime)) mime = 'video/webm;codecs=vp8,opus';
    if (!MediaRecorder.isTypeSupported(mime)) mime = 'video/webm';
    if (!MediaRecorder.isTypeSupported(mime)) mime = '';
    this.mediaRecorder = new MediaRecorder(this.cameraStream, { mimeType: mime });
    this.mediaRecorder.ondataavailable = (e) => { if (e.data.size > 0) this.recordedChunks.push(e.data); };
    this.mediaRecorder.onstop = () => this.onRecordingComplete();
    this.mediaRecorder.start(1000);
    this.recording.set(true);
    this.recordingTime.set(0);
    this.recordingTimer = setInterval(() => this.recordingTime.update(t => t + 1), 1000);
  }

  stopRecording() {
    if (this.mediaRecorder?.state !== 'inactive') this.mediaRecorder?.stop();
    this.recording.set(false);
    if (this.recordingTimer) { clearInterval(this.recordingTimer); this.recordingTimer = null; }
  }

  private onRecordingComplete() {
    const blob = new Blob(this.recordedChunks, { type: 'video/webm' });
    this.videoFile = new File([blob], `quinch-video-${Date.now()}.webm`, { type: 'video/webm' });
    this.videoPreview.set(URL.createObjectURL(blob));
    this.detectVideoResolution(this.videoFile);
    this.stopCamera();
    this.cameraMode.set(false);
    this.openVideoEditor();
  }

  stopCamera() { if (this.cameraStream) { this.cameraStream.getTracks().forEach(t => t.stop()); this.cameraStream = null; } }
  cancelCamera() { this.stopRecording(); this.stopCamera(); this.cameraMode.set(false); }

  formatRecordingTime(): string { const t = this.recordingTime(), m = Math.floor(t / 60), s = t % 60; return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`; }
  formatTime(sec: number): string { const m = Math.floor(sec / 60), s = Math.floor(sec % 60); return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`; }
  removeVideo() { this.videoFile = null; this.videoId.set(''); this.videoPreview.set(''); this.videoResolution.set(''); }

  // ═══════ IMAGES ═══════
  onImagesSelected(event: Event) {
    const input = event.target as HTMLInputElement;
    if (input.files) {
      const files = Array.from(input.files).slice(0, 5 - this.imageFiles.length);
      for (const file of files) {
        if (file.size > 10 * 1024 * 1024) { this.notify.error(`Image ${file.name} trop lourde (max 10 Mo)`); continue; }
        this.imageFiles.push(file);
        this.imagePreviews.update(p => [...p, URL.createObjectURL(file)]);
      }
    }
    input.value = '';
  }

  removeImage(index: number) {
    this.imageFiles.splice(index, 1);
    this.imagePreviews.update(p => p.filter((_, i) => i !== index));
    if (this.editingImageIdx() === index) this.editingImageIdx.set(null);
  }

  openImageEditor(index: number) { this.editingImageIdx.set(index); this.activeFilter.set('none'); }
  closeImageEditor() { this.editingImageIdx.set(null); }
  applyFilter(filterId: string) { this.activeFilter.set(filterId); }
  getFilterCss(filterId: string): string { return this.photoFilters.find(f => f.id === filterId)?.css || ''; }

  saveFilteredImage() {
    const idx = this.editingImageIdx();
    if (idx === null) return;
    const filter = this.photoFilters.find(f => f.id === this.activeFilter());
    if (!filter || filter.id === 'none') { this.editingImageIdx.set(null); return; }
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => {
      const c = document.createElement('canvas'); c.width = img.naturalWidth; c.height = img.naturalHeight;
      const ctx = c.getContext('2d')!; ctx.filter = filter.css; ctx.drawImage(img, 0, 0);
      c.toBlob((blob) => {
        if (blob) { this.imageFiles[idx] = new File([blob], this.imageFiles[idx].name, { type: 'image/jpeg' }); this.imagePreviews.update(p => p.map((u, i) => i === idx ? URL.createObjectURL(blob) : u)); }
        this.editingImageIdx.set(null);
      }, 'image/jpeg', 0.92);
    };
    img.src = this.imagePreviews()[idx];
  }

  // Toggle helpers for template (arrow fns not allowed in templates)
  toggleBold() { this.newTextBold.update(v => !v); }
  toggleShadow() { this.newTextShadow.update(v => !v); }
  toggleStroke() { this.newTextStroke.update(v => !v); }
  toggleBg() { this.newTextBg.update(v => !v); }

  toggleSelectedBold() { if (this.selectedTextIdx() !== null) this.updateSelectedText('bold', !this.textOverlays()[this.selectedTextIdx()!].bold); else this.toggleBold(); }
  toggleSelectedShadow() { if (this.selectedTextIdx() !== null) this.updateSelectedText('hasShadow', !this.textOverlays()[this.selectedTextIdx()!].hasShadow); else this.toggleShadow(); }
  toggleSelectedStroke() { if (this.selectedTextIdx() !== null) this.updateSelectedText('hasStroke', !this.textOverlays()[this.selectedTextIdx()!].hasStroke); else this.toggleStroke(); }
  toggleSelectedBg() { if (this.selectedTextIdx() !== null) this.updateSelectedText('hasBg', !this.textOverlays()[this.selectedTextIdx()!].hasBg); else this.toggleBg(); }

  onDescriptionKeydown(event: KeyboardEvent) {}
  insertHashtag() { if (this.form.description.length > 0 && !this.form.description.endsWith(' ')) this.form.description += ' '; this.form.description += '#'; }
  insertMention() { if (this.form.description.length > 0 && !this.form.description.endsWith(' ')) this.form.description += ' '; this.form.description += '@'; }

  // ═══════ PAYMENT METHODS ═══════
  togglePaymentMethod(id: string) {
    this.selectedPaymentMethods.update(methods => {
      if (methods.includes(id)) {
        return methods.filter(m => m !== id);
      } else {
        return [...methods, id];
      }
    });
  }

  isPaymentSelected(id: string): boolean {
    return this.selectedPaymentMethods().includes(id);
  }

  getPaymentMethodName(id: string): string {
    return this.availablePaymentMethods.find(m => m.id === id)?.name || id;
  }

  submit() {
    const isService = this.publishType() === 'service';
    if (!this.form.title || !this.form.category_id) { this.notify.error('Veuillez remplir tous les champs obligatoires.'); return; }
    if (!isService && !this.form.price) { this.notify.error('Veuillez indiquer un prix.'); return; }
    if (isService && this.servicePriceType() !== 'quote' && !this.form.price) { this.notify.error('Veuillez indiquer un tarif.'); return; }
    if (!this.posterFile) { this.notify.error('L\'image d\'affiche est obligatoire.'); return; }
    this.loading.set(true);

    const formData = new FormData();
    // Append core form fields (convert booleans to 1/0 for FormData compatibility)
    const fieldsToAppend = ['title', 'description', 'category_id', 'price', 'type', 'is_negotiable'];
    if (!isService) {
      fieldsToAppend.push('stock_quantity', 'condition', 'return_policy', 'warranty');
    } else {
      fieldsToAppend.push('service_type', 'availability', 'duration', 'service_area', 'experience_years');
    }
    fieldsToAppend.forEach(key => {
      const val = (this.form as any)[key];
      if (val !== null && val !== undefined && val !== '') {
        if (typeof val === 'boolean') {
          formData.append(key, val ? '1' : '0');
        } else {
          formData.append(key, String(val));
        }
      }
    });

    // Service price type
    if (isService) {
      formData.append('price_type', this.servicePriceType());
    }

    // Append video ID if available
    if (this.videoId()) {
      formData.append('video_id', this.videoId());
    }
    // Append poster image (required)
    formData.append('poster_file', this.posterFile);
    // Append additional images
    this.imageFiles.forEach(file => {
      formData.append('image_files[]', file);
    });
    // Append selected payment methods
    if (this.selectedPaymentMethods().length > 0) {
      formData.append('payment_methods', JSON.stringify(this.selectedPaymentMethods()));
    }
    // Append delivery options (products only)
    if (!isService) {
      formData.append('delivery_option', this.deliveryOption());
      if (this.deliveryOption() === 'fixed' && this.deliveryFee() > 0) {
        formData.append('delivery_fee', String(this.deliveryFee()));
      }
    }

    this.productService.createProductWithPoster(formData).subscribe({
      next: () => { this.loading.set(false); this.notify.success(isService ? 'Service publie avec succes!' : 'Produit publie avec succes!'); this.router.navigate(['/feed']); },
      error: (err) => { this.loading.set(false); this.notify.error(err.error?.message || 'Erreur lors de la publication'); },
    });
  }
}

interface TextOverlay {
  text: string;
  color: string;
  size: number;
  x: number;
  y: number;
  font: string;
  hasBg: boolean;
  bgOpacity: number;
  bgColor: string;
  hasStroke: boolean;
  hasShadow: boolean;
  rotation: number;
  bold: boolean;
}
