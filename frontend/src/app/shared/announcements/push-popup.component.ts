import { Component, effect, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { NotificationService, Announcement } from '../../core/services/notification.service';
import { AuthService } from '../../core/services/auth.service';

const SEEN_KEY = 'quinch_pushed_ids';

/**
 * « Push » in-app : dès qu'une annonce importante de l'admin arrive (bienvenue
 * juste après l'inscription, correction effectuée…), une carte glisse en haut
 * de l'écran, une seule fois par annonce, quelle que soit la page.
 */
@Component({
  selector: 'app-push-popup',
  standalone: true,
  template: `
    @if (current(); as a) {
      <div class="pp" role="alert" (click)="open(a)">
        <span class="material-icons pp-ico">{{ a.type === 'welcome' ? 'waving_hand' : 'campaign' }}</span>
        <div class="pp-txt">
          <strong>{{ a.title }}</strong>
          <span>{{ a.body }}</span>
        </div>
        <button type="button" class="pp-x" (click)="close($event)" aria-label="Fermer"><span class="material-icons">close</span></button>
      </div>
    }
  `,
  styles: [`
    .pp { position: fixed; z-index: 4000; top: calc(10px + env(safe-area-inset-top, 0px)); left: 50%; transform: translateX(-50%);
      width: min(520px, calc(100vw - 20px)); display: flex; gap: 12px; align-items: flex-start; padding: 12px 40px 12px 14px;
      border-radius: 16px; cursor: pointer; color: #f8fafc; background: rgba(20, 22, 40, .96); backdrop-filter: blur(14px);
      border: 1px solid rgba(255,255,255,.12); box-shadow: 0 18px 50px rgba(0,0,0,.45); animation: pp-in .4s cubic-bezier(.2,.9,.3,1.2); }
    @keyframes pp-in { from { opacity: 0; transform: translate(-50%, -24px); } to { opacity: 1; transform: translate(-50%, 0); } }
    .pp-ico { flex: 0 0 auto; width: 38px; height: 38px; display: grid; place-items: center; border-radius: 12px; font-size: 22px;
      background: linear-gradient(135deg, #10b981, #6366f1); color: #fff; }
    .pp-txt { min-width: 0; display: flex; flex-direction: column; gap: 2px; }
    .pp-txt strong { font-size: .92rem; }
    .pp-txt span { font-size: .8rem; opacity: .78; line-height: 1.4; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
    .pp-x { position: absolute; top: 8px; right: 8px; width: 28px; height: 28px; display: grid; place-items: center; border: 0; border-radius: 50%;
      background: transparent; color: inherit; opacity: .6; cursor: pointer; }
    .pp-x .material-icons { font-size: 18px; }
  `],
})
export class PushPopupComponent {
  private notif = inject(NotificationService);
  private auth = inject(AuthService);
  private router = inject(Router);

  current = signal<Announcement | null>(null);
  private timer: any;
  private checked = false;

  constructor() {
    effect(() => {
      const ready = this.auth.isAuthenticated() && !!this.auth.user()?.phone_verified;
      if (!ready) { this.checked = false; this.current.set(null); return; }
      if (this.checked) return;
      this.checked = true;
      this.notif.loadAnnouncements().subscribe({
        next: () => this.showNext(),
        error: () => {},
      });
    });
  }

  private seen(): string[] {
    try { return JSON.parse(localStorage.getItem(SEEN_KEY) || '[]'); } catch { return []; }
  }

  private showNext() {
    const seen = this.seen();
    const next = this.notif.announcements().find(a => !seen.includes(a.id));
    if (!next) return;
    try { localStorage.setItem(SEEN_KEY, JSON.stringify([next.id, ...seen].slice(0, 50))); } catch { /* ignore */ }
    this.current.set(next);
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.current.set(null), 9000);
  }

  close(e: Event) { e.stopPropagation(); clearTimeout(this.timer); this.current.set(null); }

  open(a: Announcement) {
    clearTimeout(this.timer);
    this.current.set(null);
    const url = a.action_url || (a.type === 'welcome' ? '/profile/edit' : '/guide/index.html');
    if (url.startsWith('/guide')) { window.location.assign(url); return; }
    if (url.startsWith('/') && !url.startsWith('//')) this.router.navigateByUrl(url);
  }
}
