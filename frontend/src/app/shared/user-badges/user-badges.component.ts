import { Component, computed, input } from '@angular/core';

export interface UserBadgeLite {
  type: string;
  name: string;
  icon: string;
  color: string;
}

/**
 * Rangée de badges d'un utilisateur — composant unique réutilisé partout
 * (cartes, feed, messages, notifications, classement, profils).
 * Le badge Premium est ajouté automatiquement si `premium` est vrai et qu'il
 * n'est pas déjà dans la liste.
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
  premium = input<boolean>(false);
  max = input<number>(3);

  private all = computed<UserBadgeLite[]>(() => {
    const list = [...(this.badges() ?? [])];
    if (this.premium() && !list.some(b => b.type === 'premium')) {
      list.unshift({ type: 'premium', name: 'Premium', icon: 'workspace_premium', color: '#f59e0b' });
    }
    return list;
  });

  shown = computed(() => this.all().slice(0, this.max()));
  extra = computed(() => Math.max(0, this.all().length - this.max()));
}
