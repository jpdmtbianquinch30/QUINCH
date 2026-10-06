import { Component, computed, input } from '@angular/core';

export interface UserBadgeLite {
  type: string;
  name: string;
  icon: string;
  color: string;
  description?: string;
  /** Zones d'affichage configurées par l'admin (voir ZONES ci-dessous). Absent = partout. */
  zones?: string[];
}

/**
 * Zones d'affichage possibles d'un badge. Chaque badge créé par l'admin
 * choisit les zones où il apparaît (page admin « Badges »). Ces identifiants
 * DOIVENT rester identiques à backend/app/Models/BadgeDefinition.php::ZONES.
 */
export const BADGE_ZONES = [
  'feed', 'explorer', 'video_feed', 'product_detail', 'seller_profile',
  'messages', 'search', 'notifications', 'rankings', 'profile',
] as const;
export type BadgeZone = (typeof BADGE_ZONES)[number];

/**
 * Rangée de badges d'un utilisateur — composant unique réutilisé partout
 * (cartes, feed, messages, notifications, classement, profils).
 *
 * Source de vérité UNIQUE : les badges créés dans l'admin (table
 * badge_definitions). Aucun badge n'est plus ajouté « en dur » côté front
 * (l'ancien badge Premium automatique a été supprimé : le Premium est
 * désormais un badge admin relié à la règle automatique « abonnement
 * Premium actif »).
 *
 * Usage : <app-user-badges [badges]="user.badges" zone="messages" [max]="4" />
 */
@Component({
  selector: 'app-user-badges',
  standalone: true,
  template: `
    @for (b of shown(); track b.type) {
      <span class="ub-chip" [style.color]="b.color" [title]="b.name" [attr.aria-label]="b.name">
        <span class="material-icons">{{ b.icon }}</span>
      </span>
    }
    @if (extra() > 0) {
      <span class="ub-more">+{{ extra() }}</span>
    }
  `,
  styles: [`
    :host { display: inline-flex; align-items: center; gap: 3px; vertical-align: middle; flex-shrink: 0; }
    .ub-chip { display: inline-flex; line-height: 1; }
    .ub-chip .material-icons { font-size: 15px; }
    .ub-more { font-size: 0.65rem; font-weight: 700; opacity: 0.7; }
  `],
})
export class UserBadgesComponent {
  badges = input<UserBadgeLite[] | null | undefined>([]);
  /** Zone d'affichage courante : seuls les badges configurés pour cette zone sont montrés. */
  zone = input<BadgeZone | string | null>(null);
  max = input<number>(4);

  private all = computed<UserBadgeLite[]>(() => {
    const zone = this.zone();
    return (this.badges() ?? []).filter(b => {
      if (!b || !b.icon) return false;
      // Pas de zone demandée, ou badge sans liste de zones : on l'affiche.
      if (!zone || !b.zones) return true;
      return b.zones.includes(zone);
    });
  });

  shown = computed(() => this.all().slice(0, this.max()));
  extra = computed(() => Math.max(0, this.all().length - this.max()));
}
