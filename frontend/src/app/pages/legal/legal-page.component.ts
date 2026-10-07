import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { LegalInfo, LegalService } from '../../core/services/legal.service';
import { LEGAL_DOCS, LegalDocKey, buildLegalDocument } from './legal-content';

/**
 * Page légale publique (conditions, confidentialité, mentions légales).
 * Le document affiché est choisi par `data.doc` dans app.routes.ts.
 */
@Component({
  selector: 'app-legal-page',
  standalone: true,
  imports: [RouterLink],
  template: `
    <main class="legal">
      <a routerLink="/feed" class="back">
        <span class="material-icons">arrow_back</span>
        Retour à QUINCH
      </a>

      <h1>{{ doc().title }}</h1>
      @if (doc().version) {
        <p class="meta">Version {{ doc().version }}</p>
      }

      @for (section of doc().sections; track section.title) {
        <section>
          <h2>{{ section.title }}</h2>
          @for (paragraph of section.paragraphs; track $index) {
            <p>{{ paragraph }}</p>
          }
        </section>
      }

      <nav class="legal-nav" aria-label="Autres documents">
        @for (link of links; track link.key) {
          <a [routerLink]="link.path" [class.active]="link.key === key()">{{ link.label }}</a>
        }
      </nav>
    </main>
  `,
  styles: [`
    :host { display: block; min-height: 100vh; background: var(--q-bg-primary, #0b0b12); }
    .legal {
      max-width: 760px;
      margin: 0 auto;
      padding: 24px 20px 64px;
      color: var(--q-text-primary, #f4f4f5);
      line-height: 1.65;
    }
    .back {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      margin-bottom: 20px;
      font-size: 0.9rem;
      color: var(--q-accent-light, #818cf8);
      text-decoration: none;
    }
    .back .material-icons { font-size: 18px; }
    h1 { font-size: 1.7rem; margin: 0 0 4px; }
    .meta { margin: 0 0 24px; font-size: 0.85rem; color: var(--q-text-secondary, #a1a1aa); }
    h2 { font-size: 1.1rem; margin: 28px 0 8px; }
    p { margin: 0 0 10px; color: var(--q-text-secondary, #d4d4d8); font-size: 0.95rem; }
    .legal-nav {
      display: flex;
      flex-wrap: wrap;
      gap: 8px 18px;
      margin-top: 40px;
      padding-top: 20px;
      border-top: 1px solid var(--q-border, #27272a);
    }
    .legal-nav a { font-size: 0.9rem; color: var(--q-text-secondary, #a1a1aa); text-decoration: none; }
    .legal-nav a.active { color: var(--q-accent-light, #818cf8); font-weight: 600; }
  `],
})
export class LegalPageComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private legal = inject(LegalService);

  readonly links = LEGAL_DOCS;
  readonly key = signal<LegalDocKey>('cgu');
  private readonly info = signal<LegalInfo | null>(null);

  /** Recalculé quand les informations légales du serveur arrivent. */
  readonly doc = computed(() => buildLegalDocument(this.key(), this.info()));

  ngOnInit(): void {
    this.key.set((this.route.snapshot.data['doc'] as LegalDocKey) ?? 'cgu');

    // En cas d'erreur réseau, le texte s'affiche quand même (champs « [à compléter] »).
    this.legal.getInfo().subscribe({
      next: (info) => this.info.set(info),
      error: () => this.info.set(null),
    });
  }
}
