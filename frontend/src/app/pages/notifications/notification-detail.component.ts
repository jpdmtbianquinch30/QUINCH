import { Component, ElementRef, OnInit, computed, inject, signal, viewChild } from '@angular/core';
import { DatePipe, Location } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { NotificationService, NotificationDetailResponse, NotificationAppeal } from '../../core/services/notification.service';

interface KindStyle { label: string; icon: string; tone: 'amber' | 'red' | 'orange' | 'green' | 'blue' | 'accent'; sanction: boolean; }

const KINDS: Record<string, KindStyle> = {
  warning: { label: 'Avertissement', icon: 'warning', tone: 'amber', sanction: true },
  suspension: { label: 'Suspension', icon: 'pause_circle', tone: 'red', sanction: true },
  ban: { label: 'Bannissement', icon: 'block', tone: 'red', sanction: true },
  reactivation: { label: 'Compte réactivé', icon: 'check_circle', tone: 'green', sanction: false },
  video_removed: { label: 'Vidéo retirée', icon: 'videocam_off', tone: 'orange', sanction: true },
  video_review: { label: 'Vidéo en révision', icon: 'rate_review', tone: 'amber', sanction: false },
  video_restored: { label: 'Vidéo rétablie', icon: 'restore', tone: 'green', sanction: false },
  product_hidden: { label: 'Produit masqué', icon: 'visibility_off', tone: 'orange', sanction: true },
  product_deleted: { label: 'Produit supprimé', icon: 'delete', tone: 'orange', sanction: true },
  product_restored: { label: 'Produit rétabli', icon: 'restore', tone: 'green', sanction: false },
  appeal_result: { label: 'Résultat de contestation', icon: 'gavel', tone: 'blue', sanction: false },
  appeal_received: { label: 'Contestation reçue', icon: 'mark_email_read', tone: 'blue', sanction: false },
  premium_granted: { label: 'Premium activé', icon: 'workspace_premium', tone: 'green', sanction: false },
  premium_revoked: { label: 'Premium retiré', icon: 'workspace_premium', tone: 'amber', sanction: false },
  dispute_resolved: { label: 'Litige résolu', icon: 'handshake', tone: 'blue', sanction: false },
  ticket_reply: { label: 'Réponse du support', icon: 'support_agent', tone: 'blue', sanction: false },
  review_removed: { label: 'Avis retiré', icon: 'rate_review', tone: 'orange', sanction: true },
  report_processed: { label: 'Signalement traité', icon: 'flag', tone: 'blue', sanction: false },
  kyc: { label: 'Vérification d\'identité', icon: 'verified_user', tone: 'green', sanction: false },
  team_message: { label: 'Message de l\'équipe', icon: 'campaign', tone: 'accent', sanction: false },
};
const DEFAULT_KIND: KindStyle = { label: 'Message de l\'équipe', icon: 'campaign', tone: 'accent', sanction: false };

@Component({
  selector: 'app-notification-detail',
  standalone: true,
  imports: [DatePipe, FormsModule],
  template: `
    <div class="nd">
      <header class="nd-top">
        <button type="button" class="nd-back" (click)="back()" aria-label="Retour">
          <span class="material-icons">arrow_back</span>
        </button>
        <span class="nd-top-title">Message de l'équipe</span>
        <span class="nd-top-spacer"></span>
      </header>

      @if (loading()) {
        <div class="nd-skel" aria-busy="true" aria-label="Chargement du message">
          <div class="sk sk-badge"></div>
          <div class="sk sk-line w60"></div>
          <div class="sk sk-line w40"></div>
          <div class="sk sk-card"></div>
        </div>
      } @else if (error()) {
        <div class="nd-error" role="alert">
          <span class="material-icons">cloud_off</span>
          <h2>Message introuvable</h2>
          <p>{{ error() }}</p>
          <div class="nd-row">
            <button type="button" class="btn primary" (click)="load()"><span class="material-icons">refresh</span>Réessayer</button>
            <button type="button" class="btn ghost" (click)="back()">Retour</button>
          </div>
        </div>
      } @else if (detail(); as d) {
        <article class="nd-main">
          <div class="nd-hero">
            <div class="nd-logo"><img src="logoquinch.png" alt="QUINCH" /></div>
            <div class="nd-from">
              <div class="nd-sender">
                Équipe QUINCH
                <span class="material-icons verified" aria-label="Compte vérifié" title="Compte vérifié">verified</span>
              </div>
              <time class="nd-date" [attr.datetime]="d.notification.created_at">
                {{ d.notification.created_at | date: "d MMMM y 'à' HH:mm" : undefined : 'fr' }}
              </time>
            </div>
          </div>

          <div class="nd-chips">
            <span class="chip kind" [attr.data-tone]="kind().tone">
              <span class="material-icons">{{ kind().icon }}</span>{{ kind().label }}
            </span>
            <button type="button" class="chip read" [class.is-read]="isRead()" (click)="toggleRead()"
              [attr.aria-pressed]="isRead()" [attr.aria-label]="isRead() ? 'Marquer comme pas lu' : 'Marquer comme lu'">
              <span class="material-icons">{{ isRead() ? 'drafts' : 'mark_email_unread' }}</span>
              {{ isRead() ? 'Lu' : 'Pas lu' }}
            </button>
          </div>

          <h1 class="nd-title">{{ d.notification.title }}</h1>

          <section class="letter" aria-label="Message">
            <div class="letter-body">{{ d.notification.body }}</div>
            <div class="letter-sign">
              <img src="logoquinch.png" alt="" /> L'équipe QUINCH
            </div>
          </section>

          @if (d.guide_anchor) {
            <a class="guide-btn" [href]="guideUrl()">
              <span class="material-icons">menu_book</span>
              <span class="guide-txt">
                <strong>{{ kind().sanction ? 'Comprendre cette décision dans le guide' : "Voir l'explication dans le guide" }}</strong>
                <small>Règles de la communauté QUINCH</small>
              </span>
              <span class="material-icons">arrow_forward</span>
            </a>
          }

          @if (d.contest; as c) {
            <section class="contest" aria-labelledby="ct-title">
              @if (c.appeal; as ap) {
                <h2 id="ct-title" class="ct-h">{{ c.type === 'message' ? 'Votre conversation avec l\\'équipe' : 'Votre contestation' }}</h2>
                <div class="status" [attr.data-status]="ap.status" role="status" aria-live="polite">
                  <span class="material-icons">{{ statusIcon(ap) }}</span>
                  <div>
                    <strong>{{ statusLabel(ap) }}</strong>
                    <small>{{ statusHint(ap) }}</small>
                  </div>
                </div>
                <ol class="steps" aria-label="Avancement">
                  <li class="done">Envoyée</li>
                  <li [class.done]="ap.status !== 'pending'" [class.now]="ap.status === 'pending'">Examen</li>
                  <li [class.done]="ap.status !== 'pending'" [attr.data-status]="ap.status">{{ ap.status === 'accepted' ? 'Acceptée' : ap.status === 'rejected' ? 'Refusée' : 'Décision' }}</li>
                </ol>
                <div class="convo">
                  <div class="msg me">
                    <span class="who">Votre message</span>
                    <div class="bubble">{{ ap.message }}</div>
                    <time>{{ ap.created_at | date: "d MMM, HH:mm" : undefined : 'fr' }}</time>
                  </div>
                  @if (ap.response) {
                    <div class="msg team">
                      <img class="av" src="logoquinch.png" alt="" />
                      <div class="col">
                        <span class="who">Équipe QUINCH</span>
                        <div class="bubble">{{ ap.response }}</div>
                        @if (ap.handled_at) { <time>{{ ap.handled_at | date: "d MMM, HH:mm" : undefined : 'fr' }}</time> }
                      </div>
                    </div>
                  }
                </div>
                @if (ap.status === 'rejected') {
                  <p class="final"><span class="material-icons">lock</span>Cette décision est définitive.</p>
                }
              }

              @if (sent()) {
                <div class="sent" role="status" aria-live="polite" tabindex="-1" #sentBox>
                  <span class="material-icons">task_alt</span>
                  <div>
                    <strong>Votre message a bien été envoyé à l'équipe.</strong>
                    <small>Nous l'examinerons dans les meilleurs délais. Vous serez notifié de la réponse.</small>
                  </div>
                </div>
              }

              @if (c.can_contest && !c.appeal && !sent()) {
                <h2 id="ct-title" class="ct-h">{{ c.type === 'message' ? "Répondre à l'équipe" : "Vous n'êtes pas d'accord ?" }}</h2>
                <p class="ct-help">
                  @if (c.type === 'message') {
                    Vous pouvez répondre directement à l'équipe QUINCH. Soyez clair et courtois.
                  } @else {
                    Si vous pensez qu'il s'agit d'une erreur, expliquez-nous votre situation. Un membre de l'équipe relira votre cas
                    et vous répondra. Vous ne pouvez contester qu'une seule fois.
                  }
                </p>
                <form (ngSubmit)="submit()" novalidate>
                  <label class="sr" for="ct-msg">Votre message</label>
                  <textarea id="ct-msg" name="message" rows="5" maxlength="2000" [(ngModel)]="text"
                    (ngModelChange)="touched.set(true)" [attr.aria-invalid]="showErr()" aria-describedby="ct-count ct-err"
                    placeholder="Expliquez votre point de vue (10 caractères minimum)…" [disabled]="sending()"></textarea>
                  <div class="ct-meta">
                    <span id="ct-err" class="err" role="alert">{{ showErr() ? errMsg() : '' }}</span>
                    <span id="ct-count" class="count" [class.low]="len() < 10">{{ len() }}/2000</span>
                  </div>
                  <button type="submit" class="btn primary wide" [disabled]="sending()">
                    <span class="material-icons">{{ sending() ? 'hourglass_top' : 'send' }}</span>
                    {{ sending() ? 'Envoi…' : c.type === 'message' ? "Répondre à l'équipe" : 'Contester cette décision' }}
                  </button>
                </form>
              }
            </section>
          }
        </article>
      }
    </div>
  `,
  styles: [`
    :host { display: block; min-height: 100vh; background: var(--q-bg-primary, #070a14); color: var(--q-text-primary, #f7f8ff); }
    .nd { --tone: var(--q-accent, #6378ff); width: min(100%, 720px); margin: 0 auto; padding: 0 16px 80px; position: relative; }
    .nd::before { content: ''; position: absolute; inset: 0 0 auto 0; height: 320px; pointer-events: none; z-index: 0;
      background: radial-gradient(60% 100% at 50% 0%, color-mix(in srgb, var(--q-accent, #6378ff) 22%, transparent), transparent 70%); }
    .nd > * { position: relative; z-index: 1; }
    .material-icons { font-size: 20px; }
    .nd-top { display: flex; align-items: center; gap: 8px; padding: 12px 0; position: sticky; top: 0; z-index: 5;
      background: color-mix(in srgb, var(--q-bg-primary, #070a14) 85%, transparent); backdrop-filter: blur(10px); }
    .nd-back { width: 40px; height: 40px; border-radius: 50%; border: 1px solid var(--q-border, rgba(255,255,255,.1)); background: var(--q-bg-card, #14141f);
      color: inherit; display: grid; place-items: center; cursor: pointer; }
    .nd-back:hover { border-color: var(--q-accent, #6378ff); }
    .nd-top-title { flex: 1; text-align: center; font-weight: 800; font-size: .95rem; }
    .nd-top-spacer { width: 40px; }
    button:focus-visible, a:focus-visible, textarea:focus-visible { outline: 2px solid var(--q-accent, #6378ff); outline-offset: 2px; }

    .nd-hero { display: flex; align-items: center; gap: 14px; margin: 14px 0 16px; }
    .nd-logo { width: 64px; height: 64px; border-radius: 50%; padding: 3px; flex: 0 0 auto;
      background: linear-gradient(135deg, var(--q-accent, #6378ff), #9b6cff, #38bdf8);
      box-shadow: 0 0 0 4px color-mix(in srgb, var(--q-accent, #6378ff) 18%, transparent), 0 0 32px color-mix(in srgb, var(--q-accent, #6378ff) 55%, transparent);
      animation: glow 3.2s ease-in-out infinite; }
    .nd-logo img { width: 100%; height: 100%; border-radius: 50%; object-fit: cover; background: var(--q-bg-card, #14141f); display: block; }
    @keyframes glow { 50% { box-shadow: 0 0 0 7px color-mix(in srgb, var(--q-accent, #6378ff) 10%, transparent), 0 0 44px color-mix(in srgb, var(--q-accent, #6378ff) 70%, transparent); } }
    .nd-sender { display: flex; align-items: center; gap: 5px; font-size: 1.1rem; font-weight: 800; }
    .verified { color: #38bdf8; font-size: 20px; }
    .nd-date { font-size: .8rem; color: var(--q-text-secondary, #8b93ad); }

    .nd-chips { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
    .chip { display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: 999px; font: inherit; font-size: .8rem; font-weight: 800;
      border: 1px solid var(--q-border, rgba(255,255,255,.1)); background: var(--q-bg-card, #14141f); color: inherit; }
    .chip .material-icons { font-size: 17px; }
    .chip.kind { --c: var(--q-accent, #6378ff); color: var(--c); border-color: color-mix(in srgb, var(--c) 40%, transparent); background: color-mix(in srgb, var(--c) 13%, transparent); }
    .chip.kind[data-tone=amber] { --c: #f59e0b; } .chip.kind[data-tone=red] { --c: #ef4444; } .chip.kind[data-tone=orange] { --c: #f97316; }
    .chip.kind[data-tone=green] { --c: #22c77a; } .chip.kind[data-tone=blue] { --c: #3b82f6; }
    .chip.read { cursor: pointer; margin-left: auto; transition: transform .15s; }
    .chip.read:hover { transform: translateY(-1px); }
    .chip.read:not(.is-read) { border-color: var(--q-accent, #6378ff); color: var(--q-accent, #6378ff); }
    .chip.read.is-read { color: var(--q-text-secondary, #8b93ad); }

    .nd-title { font-size: clamp(1.35rem, 5vw, 1.8rem); line-height: 1.22; margin: 18px 0 14px; font-weight: 900; letter-spacing: -.01em; overflow-wrap: anywhere; }

    .letter { position: relative; padding: 22px 20px 16px; border-radius: 20px; background: var(--q-bg-card, #14141f);
      border: 1px solid var(--q-border, rgba(255,255,255,.1)); box-shadow: 0 14px 40px rgba(0,0,0,.18); }
    .letter::before { content: ''; position: absolute; left: 0; top: 18px; bottom: 18px; width: 4px; border-radius: 0 4px 4px 0; background: linear-gradient(var(--q-accent, #6378ff), #9b6cff); }
    .letter-body { white-space: pre-wrap; overflow-wrap: anywhere; line-height: 1.65; font-size: 1rem; }
    .letter-sign { display: flex; align-items: center; gap: 8px; margin-top: 18px; padding-top: 12px; border-top: 1px dashed var(--q-border, rgba(255,255,255,.12));
      font-size: .82rem; font-weight: 700; color: var(--q-text-secondary, #8b93ad); }
    .letter-sign img { width: 22px; height: 22px; border-radius: 50%; }

    .guide-btn { display: flex; align-items: center; gap: 14px; margin-top: 16px; padding: 14px 16px; border-radius: 16px; text-decoration: none; color: #fff;
      background: linear-gradient(135deg, var(--q-accent, #6378ff), #9b6cff); box-shadow: 0 10px 28px color-mix(in srgb, var(--q-accent, #6378ff) 40%, transparent); transition: transform .15s; }
    .guide-btn:hover { transform: translateY(-2px); }
    .guide-txt { flex: 1; min-width: 0; display: flex; flex-direction: column; }
    .guide-txt strong { font-size: .95rem; } .guide-txt small { opacity: .8; font-size: .75rem; }

    .contest { margin-top: 22px; padding: 20px 18px; border-radius: 20px; background: var(--q-bg-card, #14141f); border: 1px solid var(--q-border, rgba(255,255,255,.1)); }
    .ct-h { margin: 0 0 8px; font-size: 1.1rem; font-weight: 900; }
    .ct-help { margin: 0 0 14px; font-size: .88rem; line-height: 1.5; color: var(--q-text-secondary, #8b93ad); }
    textarea { width: 100%; box-sizing: border-box; resize: vertical; min-height: 120px; padding: 12px 14px; border-radius: 14px; font: inherit; line-height: 1.5;
      color: inherit; background: var(--q-bg-primary, #070a14); border: 1px solid var(--q-border, rgba(255,255,255,.14)); }
    textarea[aria-invalid=true] { border-color: #ef4444; }
    .ct-meta { display: flex; justify-content: space-between; gap: 10px; min-height: 22px; margin: 6px 2px 12px; font-size: .78rem; }
    .err { color: #ef4444; font-weight: 700; } .count { margin-left: auto; color: var(--q-text-secondary, #8b93ad); font-variant-numeric: tabular-nums; } .count.low { color: #f59e0b; }
    .btn { display: inline-flex; align-items: center; justify-content: center; gap: 8px; padding: 12px 18px; border-radius: 14px; border: 1px solid var(--q-border, rgba(255,255,255,.14));
      font: inherit; font-weight: 800; cursor: pointer; color: inherit; background: transparent; }
    .btn.primary { color: #fff; border: 0; background: linear-gradient(135deg, var(--q-accent, #6378ff), #9b6cff); }
    .btn.wide { width: 100%; } .btn:disabled { opacity: .6; cursor: progress; }
    .sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }

    .status { display: flex; gap: 12px; align-items: center; padding: 12px 14px; border-radius: 14px; --c: #f59e0b; background: color-mix(in srgb, var(--c) 12%, transparent); border: 1px solid color-mix(in srgb, var(--c) 35%, transparent); }
    .status[data-status=accepted] { --c: #22c77a; } .status[data-status=rejected] { --c: #ef4444; }
    .status .material-icons { color: var(--c); font-size: 28px; } .status strong { display: block; color: var(--c); } .status small { color: var(--q-text-secondary, #8b93ad); }
    .steps { list-style: none; display: flex; margin: 16px 0; padding: 0; gap: 6px; }
    .steps li { flex: 1; text-align: center; font-size: .72rem; font-weight: 700; padding-top: 12px; position: relative; color: var(--q-text-secondary, #8b93ad); }
    .steps li::before { content: ''; position: absolute; top: 0; left: 0; right: 0; height: 4px; border-radius: 4px; background: var(--q-border, rgba(255,255,255,.12)); }
    .steps li.done { color: var(--q-text-primary, #fff); } .steps li.done::before { background: #22c77a; }
    .steps li.now::before { background: #f59e0b; animation: pulse 1.6s ease-in-out infinite; }
    .steps li.done[data-status=rejected]::before { background: #ef4444; }
    @keyframes pulse { 50% { opacity: .4; } }
    .convo { display: flex; flex-direction: column; gap: 14px; }
    .msg { display: flex; gap: 10px; max-width: 92%; } .msg .col { display: flex; flex-direction: column; min-width: 0; }
    .msg.me { align-self: flex-end; flex-direction: column; align-items: flex-end; }
    .who { font-size: .72rem; font-weight: 800; color: var(--q-text-secondary, #8b93ad); margin-bottom: 3px; }
    .bubble { padding: 10px 14px; border-radius: 18px; white-space: pre-wrap; overflow-wrap: anywhere; line-height: 1.5; font-size: .92rem; }
    .me .bubble { color: #fff; border-bottom-right-radius: 6px; background: linear-gradient(135deg, var(--q-accent, #6378ff), #9b6cff); }
    .team .bubble { border-bottom-left-radius: 6px; background: var(--q-bg-primary, #070a14); border: 1px solid var(--q-border, rgba(255,255,255,.12)); }
    .msg time { font-size: .68rem; margin-top: 3px; color: var(--q-text-secondary, #8b93ad); }
    .av { width: 32px; height: 32px; border-radius: 50%; flex: 0 0 auto; align-self: flex-end; }
    .final { display: flex; align-items: center; gap: 6px; margin: 14px 0 0; font-size: .82rem; font-weight: 700; color: #ef4444; }
    .sent { display: flex; gap: 12px; align-items: center; margin-top: 14px; padding: 14px; border-radius: 14px; background: rgba(34,199,122,.12); border: 1px solid rgba(34,199,122,.35); }
    .sent .material-icons { color: #22c77a; font-size: 30px; } .sent small { display: block; color: var(--q-text-secondary, #8b93ad); }

    .nd-skel { display: flex; flex-direction: column; gap: 14px; padding-top: 24px; }
    .sk { border-radius: 12px; background: linear-gradient(90deg, var(--q-bg-card, #14141f) 25%, var(--q-border, rgba(255,255,255,.1)) 50%, var(--q-bg-card, #14141f) 75%); background-size: 200% 100%; animation: sh 1.4s infinite; }
    .sk-badge { width: 64px; height: 64px; border-radius: 50%; } .sk-line { height: 18px; } .w60 { width: 60%; } .w40 { width: 40%; } .sk-card { height: 180px; border-radius: 20px; }
    @keyframes sh { to { background-position: -200% 0; } }
    .nd-error { text-align: center; padding: 60px 10px; } .nd-error > .material-icons { font-size: 56px; color: var(--q-text-secondary, #8b93ad); }
    .nd-error p { color: var(--q-text-secondary, #8b93ad); } .nd-row { display: flex; gap: 10px; justify-content: center; margin-top: 16px; }

    @media (min-width: 720px) { .nd { padding: 0 24px 80px; } .letter { padding: 28px 28px 18px; } .letter-body { font-size: 1.05rem; } }
    @media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation: none !important; transition: none !important; } }
  `],
})
export class NotificationDetailComponent implements OnInit {
  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private location = inject(Location);
  private notifs = inject(NotificationService);

  private sentBox = viewChild<ElementRef<HTMLElement>>('sentBox');

  loading = signal(true);
  error = signal<string | null>(null);
  detail = signal<NotificationDetailResponse | null>(null);
  isRead = signal(true);
  sending = signal(false);
  sent = signal(false);
  touched = signal(false);
  text = '';
  private id = '';
  private autoMarked = false;
  private userSetUnread = false;

  kind = computed<KindStyle>(() => {
    const d = this.detail();
    if (!d) return DEFAULT_KIND;
    const k = d.notification.data?.kind;
    if (k && KINDS[k]) return KINDS[k];
    return d.notification.type === 'kyc' ? KINDS['kyc'] : DEFAULT_KIND;
  });

  guideUrl = computed(() => {
    const a = this.detail()?.guide_anchor;
    return a ? '/guide/index.html#' + encodeURIComponent(a) : '';
  });

  ngOnInit() {
    this.route.paramMap.subscribe(p => {
      this.id = p.get('id') || '';
      this.autoMarked = false;
      this.userSetUnread = false;
      this.sent.set(false);
      this.load();
    });
  }

  len() { return this.text.length; }
  errMsg(): string {
    const n = this.text.trim().length;
    if (n === 0) return 'Veuillez écrire votre message.';
    if (n < 10) return `Encore ${10 - n} caractère(s) minimum.`;
    return this.serverErr || '';
  }
  private serverErr = '';
  showErr(): boolean { return (this.touched() && this.text.trim().length < 10) || !!this.serverErr; }

  load() {
    this.loading.set(true);
    this.error.set(null);
    this.notifs.getOne(this.id).subscribe({
      next: res => {
        this.detail.set(res);
        this.isRead.set(!!res.notification.is_read);
        this.loading.set(false);
        this.autoMarkRead();
      },
      error: err => {
        this.loading.set(false);
        this.error.set(err?.status === 404 ? "Ce message n'existe plus ou ne vous est pas destiné." : 'Impossible de charger le message. Vérifiez votre connexion.');
      },
    });
  }

  private autoMarkRead() {
    if (this.autoMarked || this.userSetUnread || this.isRead()) return;
    this.autoMarked = true;
    this.isRead.set(true);
    this.notifs.markRead(this.id).subscribe({
      next: () => this.refreshCounts(),
      error: () => this.isRead.set(false),
    });
  }

  toggleRead() {
    const next = !this.isRead();
    const prev = this.isRead();
    this.isRead.set(next);
    this.userSetUnread = !next;
    const req = next ? this.notifs.markRead(this.id) : this.notifs.markUnread(this.id);
    req.subscribe({
      next: () => this.refreshCounts(),
      error: () => { this.isRead.set(prev); this.userSetUnread = !prev; },
    });
  }

  private refreshCounts() { this.notifs.getUnreadCount().subscribe({ error: () => {} }); }

  back() {
    if (window.history.length > 1) this.location.back();
    else this.router.navigateByUrl('/notifications');
  }

  statusLabel(a: NotificationAppeal) {
    return a.status === 'pending' ? 'Contestation en cours d\'examen' : a.status === 'accepted' ? 'Contestation acceptée' : 'Contestation refusée';
  }
  statusHint(a: NotificationAppeal) {
    return a.status === 'pending' ? 'L\'équipe examine votre message.' : a.status === 'accepted' ? 'La décision a été revue en votre faveur.' : 'Après examen, la décision est maintenue.';
  }
  statusIcon(a: NotificationAppeal) { return a.status === 'pending' ? 'hourglass_top' : a.status === 'accepted' ? 'check_circle' : 'cancel'; }

  submit() {
    this.touched.set(true);
    this.serverErr = '';
    const msg = this.text.trim();
    if (msg.length < 10 || msg.length > 2000 || this.sending()) return;
    this.sending.set(true);
    this.notifs.contest(this.id, msg).subscribe({
      next: () => {
        this.sending.set(false);
        this.sent.set(true);
        this.text = '';
        this.touched.set(false);
        this.notifs.success('Message envoyé à l\'équipe');
        this.reloadQuiet();
        setTimeout(() => this.sentBox()?.nativeElement.focus(), 50);
      },
      error: err => {
        this.sending.set(false);
        const e = err?.error;
        if (err?.status === 409) { this.notifs.info(e?.message || 'Une contestation est déjà en cours.'); this.reloadQuiet(); return; }
        this.serverErr = e?.errors?.message?.[0] || e?.message || 'Envoi impossible, réessayez.';
        this.notifs.error(this.serverErr);
      },
    });
  }

  private reloadQuiet() {
    this.notifs.getOne(this.id).subscribe({ next: r => this.detail.set(r), error: () => {} });
  }
}
