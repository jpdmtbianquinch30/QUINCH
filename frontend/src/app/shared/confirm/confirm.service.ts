import { Injectable, signal } from '@angular/core';

export interface ConfirmOptions {
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  /** Style rouge pour les actions destructrices. */
  danger?: boolean;
  icon?: string;
  /** L'utilisateur doit recopier ce mot pour activer le bouton (ex. SUPPRIMER). */
  requireText?: string;
  /** Demande le mot de passe (action sensible) : il est renvoyé dans le résultat. */
  askPassword?: boolean;
}

export interface ConfirmResult { confirmed: boolean; password: string; }

/**
 * Boîte de confirmation globale (remplace les confirm() natifs).
 * Usage : `const r = await this.confirm.ask({ title, message, danger: true }); if (!r.confirmed) return;`
 * Le composant <app-confirm-dialog /> est monté une fois dans app.html.
 */
@Injectable({ providedIn: 'root' })
export class ConfirmService {
  readonly state = signal<(ConfirmOptions & { open: boolean }) | null>(null);
  private resolver: ((r: ConfirmResult) => void) | null = null;

  ask(options: ConfirmOptions): Promise<ConfirmResult> {
    // Une seule boîte à la fois : une nouvelle demande annule la précédente.
    this.resolver?.({ confirmed: false, password: '' });
    this.state.set({ ...options, open: true });
    return new Promise<ConfirmResult>(resolve => (this.resolver = resolve));
  }

  close(result: ConfirmResult) {
    this.state.set(null);
    this.resolver?.(result);
    this.resolver = null;
  }
}
