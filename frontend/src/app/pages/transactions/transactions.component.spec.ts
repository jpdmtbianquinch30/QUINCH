import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideRouter } from '@angular/router';
import { TransactionsComponent } from './transactions.component';

describe('TransactionsComponent — logique de statut', () => {
  let component: TransactionsComponent;
  let fixture: ComponentFixture<TransactionsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TransactionsComponent],
      providers: [provideHttpClient(), provideHttpClientTesting(), provideRouter([])],
    }).compileComponents();

    fixture = TestBed.createComponent(TransactionsComponent);
    component = fixture.componentInstance;
  });

  // ─── Garde-fou anti-régression ────────────────────────────────────────
  // Ces fonctions DOIVENT reconnaître les vraies valeurs d'order_status
  // (pending_payment, processing, shipped, delivered, completed, cancelled,
  // disputed) — jamais les valeurs de payment_status (pending, completed,
  // failed, refunded), qui ne représentent qu'un état de paiement, pas de
  // traitement de commande. Un retour au fallback générique ('help', '',
  // le status brut en libellé) sur une vraie valeur d'order_status signale
  // qu'on a réintroduit le bug initial (lecture du mauvais champ).

  const realOrderStatuses = ['pending_payment', 'processing', 'shipped', 'delivered', 'completed', 'cancelled', 'disputed'];

  it('reconnaît un libellé explicite pour chaque valeur réelle de order_status', () => {
    for (const status of realOrderStatuses) {
      const label = component.getStatusLabel(status);
      expect(label).not.toBe(status); // pas de fallback "affiche la valeur brute"
    }
  });

  it('reconnaît une icône explicite pour chaque valeur réelle de order_status', () => {
    for (const status of realOrderStatuses) {
      expect(component.getStatusIcon(status)).not.toBe('help'); // 'help' = fallback générique
    }
  });

  it('attribue une classe de couleur explicite pour chaque valeur réelle de order_status', () => {
    for (const status of realOrderStatuses) {
      expect(component.getStatusClass(status)).not.toBe('');
    }
  });

  it('place "processing" avant "completed" dans la timeline, pas au même palier', () => {
    expect(component.getStatusStep('processing')).toBeLessThan(component.getStatusStep('completed'));
  });

  it('ne confond pas "pending_payment" (paiement non confirmé) avec "completed"', () => {
    expect(component.getStatusStep('pending_payment')).toBeLessThan(component.getStatusStep('completed'));
  });

  it('"shipped" et "delivered" sont bien après "processing" (commande déjà acceptée)', () => {
    expect(component.getStatusStep('shipped')).toBeGreaterThanOrEqual(component.getStatusStep('processing'));
    expect(component.getStatusStep('delivered')).toBeGreaterThanOrEqual(component.getStatusStep('processing'));
  });

  it('"cancelled" et "disputed" ne progressent jamais la timeline', () => {
    expect(component.getStatusStep('cancelled')).toBe(0);
    expect(component.getStatusStep('disputed')).toBe(0);
  });

  // ─── Moyens de paiement : seuls Wave et Orange Money doivent exister ───
  it('ne reconnaît plus free_money ni cash_delivery comme moyens de paiement valides', () => {
    expect(component.getPaymentLabel('free_money')).toBe('free_money'); // fallback = valeur brute = "non reconnu"
    expect(component.getPaymentLabel('cash_delivery')).toBe('cash_delivery');
  });

  it('reconnaît Wave et Orange Money comme moyens de paiement valides', () => {
    expect(component.getPaymentLabel('wave')).toBe('Wave');
    expect(component.getPaymentLabel('orange_money')).toBe('Orange Money');
  });
});
