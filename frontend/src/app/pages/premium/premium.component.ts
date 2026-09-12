import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule, DecimalPipe, DatePipe } from '@angular/common';
import { Router, ActivatedRoute } from '@angular/router';
import { PremiumService, PremiumPlan, PremiumStatus } from '../../core/services/premium.service';
import { NotificationService } from '../../core/services/notification.service';
import { AuthService } from '../../core/services/auth.service';

type ViewMode = 'plans' | 'success' | 'error';

/**
 * Page Premium — jamais construite côté frontend jusqu'ici alors que le
 * backend (PremiumController, webhook Wave, activation) est complet et
 * testé. Trois routes gérées ici : /premium (choix des plans ou statut
 * actuel), /premium/success et /premium/error (retour de paiement Wave,
 * URLs exactes attendues par PremiumController::subscribe()).
 */
@Component({
  selector: 'app-premium',
  standalone: true,
  imports: [CommonModule, DecimalPipe, DatePipe],
  templateUrl: './premium.component.html',
  styleUrl: './premium.component.scss',
})
export class PremiumComponent implements OnInit {
  private premiumService = inject(PremiumService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private notify = inject(NotificationService);
    private auth = inject(AuthService);

  mode = signal<ViewMode>('plans');
  loading = signal(true);
  subscribing = signal<'monthly' | 'annual' | null>(null);

  plans = signal<PremiumPlan[]>([]);
  status = signal<PremiumStatus | null>(null);

  benefits = [
    { icon: 'workspace_premium', label: 'Badge Premium doré sur votre profil et vos annonces' },
    { icon: 'trending_up', label: 'Boutique mise en avant dans le feed et le marketplace' },
    { icon: 'photo_library', label: "Jusqu'à 10 photos par annonce (au lieu de 3)" },
    { icon: 'campaign', label: 'Publication gratuite (vidéo ou photos), sans frais par annonce' },
    { icon: 'bolt', label: 'Accès aux fonctionnalités avancées (négociation, badges, collections)' },
  ];

  ngOnInit() {
    const path = this.route.snapshot.routeConfig?.path || '';
    if (path === 'premium/success') this.mode.set('success');
    else if (path === 'premium/error') this.mode.set('error');
    else this.mode.set('plans');

    this.loading.set(true);
    this.premiumService.getStatus().subscribe({
      next: (res) => {
        this.status.set(res);
        this.loading.set(false);
        // Rafraîchit l'utilisateur global (auth.user()) : sans ça, le reste
        // de l'app (frais de publication, badges...) reste sur l'ancien
        // statut premium jusqu'à une reconnexion.
        this.auth.getMe().subscribe();
      },
      error: () => this.loading.set(false),
    });

    if (this.mode() === 'plans') {
      this.premiumService.getPlans().subscribe({
        next: (res) => this.plans.set(res.plans || []),
      });
    }
  }

  subscribe(plan: 'monthly' | 'annual') {
    if (this.subscribing()) return;
    this.subscribing.set(plan);
    this.premiumService.subscribe(plan, 'wave').subscribe({
      next: (res) => {
        // Redirection réelle vers Wave — on quitte l'app le temps du paiement.
        window.location.href = res.payment_url;
      },
      error: (err) => {
        this.subscribing.set(null);
        this.notify.error(err?.error?.message || "Impossible d'initier l'abonnement pour le moment.");
      },
    });
  }

  backToApp() {
    this.router.navigate(['/feed']);
  }

  retry() {
    this.router.navigate(['/premium']);
  }

  planLabel(plan: string | null): string {
    return plan === 'annual' ? 'Annuel' : plan === 'monthly' ? 'Mensuel' : '';
  }
}
