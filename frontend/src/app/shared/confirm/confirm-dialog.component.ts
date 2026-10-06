import { Component, ElementRef, HostListener, effect, inject, signal, viewChild } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ConfirmService } from './confirm.service';

@Component({
  selector: 'app-confirm-dialog',
  standalone: true,
  imports: [FormsModule],
  template: `
    @if (svc.state(); as s) {
      <div class="cd-backdrop" (click)="cancel()">
        <div class="cd-box" role="alertdialog" aria-modal="true" aria-labelledby="cd-title" aria-describedby="cd-msg"
             (click)="$event.stopPropagation()">
          <div class="cd-icon" [class.danger]="s.danger">
            <span class="material-icons">{{ s.icon || (s.danger ? 'warning' : 'help_outline') }}</span>
          </div>
          <h3 id="cd-title">{{ s.title }}</h3>
          <p id="cd-msg">{{ s.message }}</p>

          @if (s.requireText) {
            <label class="cd-label" for="cd-text">Pour confirmer, écrivez <strong>{{ s.requireText }}</strong></label>
            <input id="cd-text" class="cd-input" autocomplete="off" [ngModel]="typed()" (ngModelChange)="typed.set($event)" />
          }
          @if (s.askPassword) {
            <label class="cd-label" for="cd-pw">Votre mot de passe</label>
            <input id="cd-pw" class="cd-input" type="password" autocomplete="current-password" [ngModel]="password()" (ngModelChange)="password.set($event)" />
          }

          <div class="cd-actions">
            <button #cancelBtn type="button" class="cd-btn" (click)="cancel()">{{ s.cancelLabel || 'Annuler' }}</button>
            <button type="button" class="cd-btn primary" [class.danger]="s.danger" [disabled]="!canConfirm()" (click)="ok()">
              {{ s.confirmLabel || 'Confirmer' }}
            </button>
          </div>
        </div>
      </div>
    }
  `,
  styles: [`
    .cd-backdrop { position: fixed; inset: 0; z-index: 10050; display: grid; place-items: center; padding: 16px;
      background: rgba(2, 6, 23, .62); backdrop-filter: blur(4px); animation: cdFade .15s ease-out; }
    .cd-box { width: min(420px, 100%); background: var(--q-bg-card, #141827); color: var(--q-text-primary, #eef1fb);
      border: 1px solid var(--q-border, rgba(255,255,255,.1)); border-radius: 20px; padding: 24px 22px 18px;
      box-shadow: 0 24px 70px rgba(0,0,0,.5); text-align: center; animation: cdPop .18s ease-out;
      max-height: calc(100dvh - 32px); overflow-y: auto; }
    .cd-icon { width: 54px; height: 54px; margin: 0 auto 12px; display: grid; place-items: center; border-radius: 50%;
      background: rgba(99,102,241,.15); color: var(--q-accent, #6366f1); }
    .cd-icon.danger { background: rgba(239,68,68,.15); color: #ef4444; }
    .cd-icon .material-icons { font-size: 28px; }
    h3 { margin: 0 0 8px; font-size: 1.1rem; font-weight: 800; }
    p { margin: 0 0 14px; font-size: .92rem; line-height: 1.5; color: var(--q-text-secondary, #9aa3bd); white-space: pre-line; }
    .cd-label { display: block; text-align: left; margin: 8px 0 6px; font-size: .8rem; color: var(--q-text-secondary, #9aa3bd); }
    .cd-input { width: 100%; box-sizing: border-box; height: 44px; padding: 0 12px; border-radius: 12px; font: inherit;
      background: var(--q-bg-primary, #0b0d16); color: inherit; border: 1px solid var(--q-border, rgba(255,255,255,.12)); }
    .cd-input:focus-visible { outline: 2px solid var(--q-accent, #6366f1); outline-offset: 1px; }
    .cd-actions { display: flex; gap: 10px; margin-top: 16px; }
    .cd-btn { flex: 1; height: 46px; border-radius: 13px; cursor: pointer; font: inherit; font-weight: 700;
      background: var(--q-bg-primary, #0b0d16); color: inherit; border: 1px solid var(--q-border, rgba(255,255,255,.12)); }
    .cd-btn.primary { border: 0; color: #fff; background: linear-gradient(135deg, var(--q-accent, #6366f1), #7c6cf6); }
    .cd-btn.primary.danger { background: linear-gradient(135deg, #ef4444, #dc2626); }
    .cd-btn:disabled { opacity: .45; cursor: not-allowed; }
    .cd-btn:focus-visible { outline: 2px solid var(--q-accent, #6366f1); outline-offset: 2px; }
    @keyframes cdFade { from { opacity: 0; } }
    @keyframes cdPop { from { opacity: 0; transform: translateY(8px) scale(.97); } }
    @media (prefers-reduced-motion: reduce) { .cd-backdrop, .cd-box { animation: none; } }
  `],
})
export class ConfirmDialogComponent {
  svc = inject(ConfirmService);
  typed = signal('');
  password = signal('');
  private cancelBtn = viewChild<ElementRef<HTMLButtonElement>>('cancelBtn');

  constructor() {
    effect(() => {
      const s = this.svc.state();
      this.typed.set('');
      this.password.set('');
      // Focus sur « Annuler » par défaut : une action destructrice n'est jamais la réponse par défaut.
      if (s) queueMicrotask(() => setTimeout(() => this.cancelBtn()?.nativeElement.focus(), 30));
    });
  }

  canConfirm(): boolean {
    const s = this.svc.state();
    if (!s) return false;
    if (s.requireText && this.typed().trim().toUpperCase() !== s.requireText.toUpperCase()) return false;
    if (s.askPassword && this.password().length < 1) return false;
    return true;
  }

  ok() { if (this.canConfirm()) this.svc.close({ confirmed: true, password: this.password() }); }
  cancel() { this.svc.close({ confirmed: false, password: '' }); }

  @HostListener('document:keydown.escape') onEsc() { if (this.svc.state()) this.cancel(); }
}
