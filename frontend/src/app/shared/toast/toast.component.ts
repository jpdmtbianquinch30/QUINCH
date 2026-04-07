import { Component, inject } from '@angular/core';
import { NotificationService } from '../../core/services/notification.service';

@Component({
  selector: 'app-toast',
  standalone: true,
  template: `
    <div class="toast-container">
      @for (toast of notif.toasts(); track toast.id) {
        <div class="toast" [class]="'toast-' + toast.type" (click)="notif.removeToast(toast.id)">
          <span class="material-icons toast-icon">
            @switch (toast.type) {
              @case ('success') { check_circle }
              @case ('error') { error }
              @case ('warning') { warning }
              @case ('info') { info }
            }
          </span>
          <span class="toast-message">{{ toast.message }}</span>
          <button class="toast-close" (click)="notif.removeToast(toast.id)">
            <span class="material-icons">close</span>
          </button>
        </div>
      }
    </div>
  `,
  styles: [`
    .toast-container {
      position: fixed;
      bottom: 24px;
      right: 24px;
      z-index: 10000;
      display: flex;
      flex-direction: column;
      gap: 8px;
      max-width: 400px;
    }
    .toast {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 14px 18px;
      border-radius: 12px;
      animation: slideInRight 0.3s ease-out;
      cursor: pointer;
      backdrop-filter: blur(12px);
      box-shadow: 0 8px 32px rgba(0,0,0,0.4);
    }
    .toast-success {
      background: rgba(34, 197, 94, 0.15);
      border: 1px solid rgba(34, 197, 94, 0.3);
      color: #86efac;
    }
    .toast-error {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.3);
      color: #fca5a5;
    }
    .toast-warning {
      background: rgba(245, 158, 11, 0.15);
      border: 1px solid rgba(245, 158, 11, 0.3);
      color: #fde68a;
    }
    .toast-info {
      background: rgba(59, 130, 246, 0.15);
      border: 1px solid rgba(59, 130, 246, 0.3);
      color: #93c5fd;
    }
    .toast-icon { font-size: 22px; }
    .toast-message { flex: 1; font-size: 0.9rem; font-weight: 500; }
    .toast-close {
      opacity: 0.6;
      .material-icons { font-size: 18px; }
      &:hover { opacity: 1; }
    }
    @keyframes slideInRight {
      from { transform: translateX(100%); opacity: 0; }
      to { transform: translateX(0); opacity: 1; }
    }

    /* Light mode overrides */
    :host-context(body.quinch-light) .toast {
      box-shadow: 0 4px 16px rgba(0,0,0,0.1);
    }
    :host-context(body.quinch-light) .toast-success {
      background: rgba(22, 163, 74, 0.1);
      border-color: rgba(22, 163, 74, 0.25);
      color: #15803d;
    }
    :host-context(body.quinch-light) .toast-error {
      background: rgba(220, 38, 38, 0.1);
      border-color: rgba(220, 38, 38, 0.25);
      color: #b91c1c;
    }
    :host-context(body.quinch-light) .toast-warning {
      background: rgba(217, 119, 6, 0.1);
      border-color: rgba(217, 119, 6, 0.25);
      color: #b45309;
    }
    :host-context(body.quinch-light) .toast-info {
      background: rgba(37, 99, 235, 0.1);
      border-color: rgba(37, 99, 235, 0.25);
      color: #1d4ed8;
    }
    :host-context(body.quinch-light) .toast-close {
      color: #374151;
    }
  `]
})
export class ToastComponent {
  notif = inject(NotificationService);
}
