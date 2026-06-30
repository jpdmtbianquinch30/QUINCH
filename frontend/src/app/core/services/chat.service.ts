import { Injectable, signal, computed, inject } from '@angular/core';
import { Observable, tap } from 'rxjs';
import { ApiService } from './api.service';

export interface Conversation {
  id: string;
  buyer_id: string;
  seller_id: string;
  product_id?: string;
  status: string;
  last_message_at: string;
  other_user: {
    id: string;
    full_name: string;
    avatar_url?: string;
    username?: string;
    is_online?: boolean;
  };
  product?: { id: string; title: string; slug: string; price: number };
  last_message?: Message; // Laravel serializes lastMessage as last_message
  unread_count: number;
}

export interface Message {
  id: string;
  conversation_id: string;
  sender_id: string;
  body: string;
  type: 'text' | 'image' | 'offer' | 'system' | 'audio' | 'file';
  metadata?: {
    audio_url?: string;
    file_url?: string;
    file_name?: string;
    file_size?: number;
    mime_type?: string;
    extension?: string;
    duration?: number;
    [key: string]: any;
  };
  is_read: boolean;
  created_at: string;
  sender?: { id: string; full_name: string; avatar_url?: string };
}

@Injectable({ providedIn: 'root' })
export class ChatService {
  private api = inject(ApiService);
  conversations = signal<Conversation[]>([]);
  currentConversation = signal<Conversation | null>(null);
  messages = signal<Message[]>([]);

  /** Total unread messages across all conversations */
  unreadTotal = computed(() =>
    this.conversations().reduce((sum, c) => sum + (c.unread_count || 0), 0)
  );

  getConversations(): Observable<any> {
    return this.api.get<any>('conversations').pipe(
      tap(res => this.conversations.set(res.data || []))
    );
  }

  startConversation(sellerId: string, message: string, productId?: string): Observable<any> {
    return this.api.post<any>('conversations/start', {
      seller_id: sellerId,
      product_id: productId,
      message,
    });
  }

  getConversation(id: string): Observable<any> {
    return this.api.get<any>(`conversations/${id}`).pipe(
      tap(res => {
        this.currentConversation.set(res.conversation);
        this.messages.set(res.conversation?.messages || []);

        // Update last_message in conversation list + reset unread count
        if (res.conversation) {
          const msgs: Message[] = res.conversation.messages || [];
          const lastMsg = msgs.length > 0 ? msgs[msgs.length - 1] : null;
          this.conversations.update(list =>
            list.map(c =>
              c.id === id
                ? { ...c, last_message: lastMsg || c.last_message, unread_count: 0 }
                : c
            )
          );
        }
      })
    );
  }

  sendMessage(conversationId: string, body: string, type = 'text', metadata?: any): Observable<any> {
    return this.api.post<any>(`conversations/${conversationId}/messages`, { body, type, metadata }).pipe(
      tap(res => {
        if (res.message) {
          // Add message to current messages list
          this.messages.update(msgs => [...msgs, res.message]);

          // Update the conversation in the list with the new last message
          const now = new Date().toISOString();
          this.conversations.update(list => {
            const updated = list.map(c =>
              c.id === conversationId
                ? { ...c, last_message: res.message, last_message_at: now }
                : c
            );
            // Sort: most recent conversation first
            return updated.sort((a, b) =>
              new Date(b.last_message_at).getTime() - new Date(a.last_message_at).getTime()
            );
          });
        }
      })
    );
  }

  sendAudioMessage(conversationId: string, audioBlob: Blob, duration: number): Observable<any> {
    const formData = new FormData();
    formData.append('audio', audioBlob, 'voice_message.webm');
    formData.append('duration', duration.toString());

    return this.api.upload<any>(`conversations/${conversationId}/audio`, formData).pipe(
      tap(res => {
        if (res.message) {
          this.messages.update(msgs => [...msgs, res.message]);
          const now = new Date().toISOString();
          this.conversations.update(list => {
            const updated = list.map(c =>
              c.id === conversationId
                ? { ...c, last_message: res.message, last_message_at: now }
                : c
            );
            return updated.sort((a, b) =>
              new Date(b.last_message_at).getTime() - new Date(a.last_message_at).getTime()
            );
          });
        }
      })
    );
  }

  sendFile(conversationId: string, file: File): Observable<any> {
    const formData = new FormData();
    formData.append('file', file, file.name);

    return this.api.upload<any>(`conversations/${conversationId}/file`, formData).pipe(
      tap(res => {
        if (res.message) {
          this.messages.update(msgs => [...msgs, res.message]);
          const now = new Date().toISOString();
          this.conversations.update(list => {
            const updated = list.map(c =>
              c.id === conversationId
                ? { ...c, last_message: res.message, last_message_at: now }
                : c
            );
            return updated.sort((a, b) =>
              new Date(b.last_message_at).getTime() - new Date(a.last_message_at).getTime()
            );
          });
        }
      })
    );
  }

  markConversationRead(conversationId: string): void {
    this.conversations.update(list =>
      list.map(c => c.id === conversationId ? { ...c, unread_count: 0 } : c)
    );
  }

  deleteConversation(conversationId: string): Observable<any> {
    return this.api.delete<any>(`conversations/${conversationId}`).pipe(
      tap(() => {
        this.conversations.update(list => list.filter(c => c.id !== conversationId));
        if (this.currentConversation()?.id === conversationId) {
          this.currentConversation.set(null);
          this.messages.set([]);
        }
      })
    );
  }
}
