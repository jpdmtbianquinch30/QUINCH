import { Component, inject, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { NotificationService, Announcement, resolveTeamNotificationUrl } from '../../core/services/notification.service';
import { AuthService } from '../../core/services/auth.service';

/**
 * Annonces de l'équipe QUINCH, affichées en haut du feed dès l'arrivée :
 *  - message de bienvenue (objectif : 80 % de score de confiance) ;
 *  - messages de l'admin (« nous avons corrigé… »).
 * Source : GET notifications/announcements. Fermer = marquer lu (la cloche suit).
 */
@Component({
  selector: 'app-announcements',
  standalone: true,
  template: `
    @for (a of notif.announcements(); track a.id) {
      <article class="ann" [class.welcome]="a.type === 'welcome'">
        <span class="ann-ico material-icons">{{ a.icon || (a.type === 'welcome' ? 'waving_hand' : 'campaign') }}</span>
        <div class="ann-body">
          <strong>{{ a.title }}</strong>
          <p>{{ a.body }}</p>
          <button type="button" class="ann-cta" (click)="open(a)">
            {{ a.type === 'welcome' ? 'Configurer mon profil' : 'Voir le détail' }}
            <span class="material-icons">arrow_forward</span>
          </button>
        </div>
        <button type="button" class="ann-x" (click)="notif.dismissAnnouncement(a.id)" aria-label="Fermer">
          <span class="material-icons">close</span>
        </button>
      </article>
    }
  `,
  styles: [`
    :host { display: block; }
    .ann { position: relative; display: flex; gap: 12px; align-items: flex-start; margin: 10px 12px 0; padding: 14px 40px 14px 14px;
      border-radius: 16px; color: var(--q-text-primary, #f3f4f6); background: var(--q-bg-card, #14141f);
      border: 1px solid var(--q-border, rgba(255,255,255,.1)); box-shadow: var(--q-shadow-sm, none);
      border-left: 4px solid #f59e0b; animation: ann-in .3s ease-out; }
    .ann.welcome { border-left-color: #10b981; background: linear-gradient(135deg, rgba(16,185,129,.12), transparent 60%), var(--q-bg-card, #14141f); }
    @keyframes ann-in { from { opacity: 0; transform: translateY(-8px); } to { opacity: 1; transform: none; } }
    .ann-ico { font-size: 26px; color: #f59e0b; flex: 0 0 auto; margin-top: 2px; }
    .welcome .ann-ico { color: #10b981; }
    .ann-body { min-width: 0; }
    .ann-body strong { display: block; font-size: .95rem; margin-bottom: 3px; }
    .ann-body p { margin: 0 0 8px; font-size: .84rem; line-height: 1.45; opacity: .8; display: -webkit-box; -webkit-line-clamp: 4; -webkit-box-orient: vertical; overflow: hidden; }
    .ann-cta { display: inline-flex; align-items: center; gap: 4px; border: 0; cursor: pointer; font: inherit; font-size: .8rem; font-weight: 800;
      color: #fff; padding: 7px 12px; border-radius: 999px; background: linear-gradient(135deg, #6366f1, #8b5cf6); }
    .ann-cta .material-icons { font-size: 15px; }
    .ann-x { position: absolute; top: 8px; right: 8px; width: 30px; height: 30px; display: grid; place-items: center; border: 0; border-radius: 50%;
      background: transparent; color: inherit; opacity: .55; cursor: pointer; }
    .ann-x:hover { opacity: 1; background: rgba(127,127,127,.18); }
    .ann-x .material-icons { font-size: 18px; }
  `],
})
export class AnnouncementsComponent implements OnInit {
  notif = inject(NotificationService);
  private auth = inject(AuthService);
  private router = inject(Router);

  ngOnInit() {
    if (this.auth.isAuthenticated() && this.auth.user()?.phone_verified) {
      this.notif.loadAnnouncements().subscribe({ error: () => {} });
    } else {
      this.notif.announcements.set([]);
    }
  }

  open(a: Announcement) {
    const url = resolveTeamNotificationUrl(a) || a.action_url || (a.type === 'welcome' ? '/profile/edit' : '/guide/index.html');
    this.notif.dismissAnnouncement(a.id);
    if (url.startsWith('/guide')) { window.location.assign(url); return; }
    if (url.startsWith('/') && !url.startsWith('//')) this.router.navigateByUrl(url);
  }
}
