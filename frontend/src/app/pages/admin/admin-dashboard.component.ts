import { Component, inject, signal, OnInit, OnDestroy, computed } from '@angular/core';
import { Router } from '@angular/router';
import { DatePipe, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AdminService, AdminUser, AdminMetrics } from '../../core/services/admin.service';
import { NotificationService } from '../../core/services/notification.service';

type AdminTab = 'dashboard' | 'users' | 'moderation' | 'finance' | 'reports' | 'security';

@Component({
  selector: 'app-admin-dashboard',
  standalone: true,
  imports: [DatePipe, FormsModule],
  templateUrl: './admin-dashboard.component.html',
  styleUrl: './admin-dashboard.component.scss',
})
export class AdminDashboardComponent implements OnInit, OnDestroy {
  private admin = inject(AdminService);
  private router = inject(Router);
  private location = inject(Location);
  private notif = inject(NotificationService);

  activeTab = signal<AdminTab>('dashboard');
  loading = signal(true);
  metrics = signal<AdminMetrics | null>(null);
  realTime = signal<any>(null);
  alerts = signal<any[]>([]);
  pendingVideos = signal<any[]>([]);

  // Users tab
  userSearchText = '';
  userFilterValue = 'all';
  userKycFilterValue = 'all';
  userPage = signal(1);
  userList = signal<AdminUser[]>([]);
  userTotal = signal(0);
  selectedUser = signal<any>(null);
  showUserDetail = signal(false);

  // User actions modals
  showSuspendModal = signal(false);
  showTrustModal = signal(false);
  showBadgeModal = signal(false);
  showNotifyModal = signal(false);
  suspendReason = '';
  suspendDuration = 7;
  trustScore = 0.5;
  trustReason = '';
  badgeType = 'verified';
  badgeReason = '';
  notifyTitle = '';
  notifyBody = '';

  // Moderation tab
  moderationTab = signal<'pending' | 'flagged' | 'reports'>('pending');
  selectedModerationIds = signal<string[]>([]);

  // Reports tab
  reportPeriod = signal(7);
  reportData = signal<any>(null);
  transactionReport = signal<any>(null);
  userReport = signal<any>(null);

  // Security
  securityLogs = signal<any[]>([]);

  private refreshInterval: any;

  // Badge definitions
  badgeDefinitions = [
    { type: 'verified', name: 'Verifie', icon: 'verified' },
    { type: 'top_seller', name: 'Top Vendeur', icon: 'emoji_events' },
    { type: 'fast_shipper', name: 'Livraison Express', icon: 'local_shipping' },
    { type: 'loyal_customer', name: 'Client Fidele', icon: 'favorite' },
    { type: 'active_reviewer', name: 'Reviewer Actif', icon: 'rate_review' },
    { type: 'premium', name: 'Premium', icon: 'star' },
    { type: 'ambassador', name: 'Ambassadeur', icon: 'campaign' },
  ];

  ngOnInit() {
    this.loadDashboard();
    this.refreshInterval = setInterval(() => this.loadRealTime(), 10000);
  }

  ngOnDestroy() {
    if (this.refreshInterval) clearInterval(this.refreshInterval);
  }

  switchTab(tab: AdminTab) {
    this.activeTab.set(tab);
    if (tab === 'users' && this.userList().length === 0) this.loadUsers();
    if (tab === 'moderation' && this.pendingVideos().length === 0) this.loadModeration();
    if (tab === 'reports' && !this.reportData()) this.loadReports();
    if (tab === 'security' && this.securityLogs().length === 0) this.loadSecurityLogs();
  }

  loadDashboard() {
    this.admin.getMetrics().subscribe({
      next: (res) => { this.metrics.set(res); this.loading.set(false); },
      error: () => this.loading.set(false),
    });
    this.loadRealTime();
    this.admin.getSecurityAlerts().subscribe({
      next: (res) => this.alerts.set(res.data || []),
    });
    this.admin.getPendingModeration().subscribe({
      next: (res) => this.pendingVideos.set(res.data || []),
    });
  }

  loadRealTime() {
    this.admin.getRealTimeData().subscribe({
      next: (res) => this.realTime.set(res),
    });
  }

  // ─── Users ─────────────────────────────────────────────────────────────
  loadUsers() {
    const params: any = { page: this.userPage(), per_page: 15 };
    if (this.userSearchText) params.search = this.userSearchText;
    if (this.userFilterValue !== 'all') params.status = this.userFilterValue;
    if (this.userKycFilterValue !== 'all') params.kyc = this.userKycFilterValue;

    this.admin.getUsers(params).subscribe({
      next: (res) => {
        this.userList.set(res.data || []);
        this.userTotal.set(res.total || 0);
      },
    });
  }

  searchUsers() { this.userPage.set(1); this.loadUsers(); }

  viewUser(user: AdminUser) {
    this.admin.getUser(user.id).subscribe({
      next: (res) => {
        this.selectedUser.set(res);
        this.showUserDetail.set(true);
      },
    });
  }

  closeUserDetail() { this.showUserDetail.set(false); this.selectedUser.set(null); }

  suspendUser() {
    const user = this.selectedUser()?.user;
    if (!user) return;
    this.admin.suspendUser(user.id, this.suspendReason, this.suspendDuration).subscribe({
      next: () => {
        this.notif.success('Utilisateur suspendu');
        this.showSuspendModal.set(false);
        this.suspendReason = '';
        this.loadUsers();
        this.closeUserDetail();
      },
    });
  }

  activateUser(id: string) {
    this.admin.activateUser(id).subscribe({
      next: () => {
        this.notif.success('Utilisateur reactive');
        this.loadUsers();
        this.closeUserDetail();
      },
    });
  }

  deleteUser() {
    const user = this.selectedUser()?.user;
    if (!user) return;
    if (!confirm('Etes-vous SUR de vouloir supprimer ce compte ? Cette action est IRREVERSIBLE.')) return;
    this.admin.deleteUser(user.id, 'Suppression admin').subscribe({
      next: () => {
        this.notif.success('Compte utilisateur supprime');
        this.loadUsers();
        this.closeUserDetail();
      },
      error: () => this.notif.error('Erreur lors de la suppression'),
    });
  }

  banUser() {
    const user = this.selectedUser()?.user;
    if (!user) return;
    this.admin.banUser(user.id, this.suspendReason || 'Bannissement permanent').subscribe({
      next: () => {
        this.notif.success('Utilisateur banni definitivement');
        this.showSuspendModal.set(false);
        this.loadUsers();
        this.closeUserDetail();
      },
      error: () => this.notif.error('Erreur lors du bannissement'),
    });
  }

  verifyKyc(id: string, status: string) {
    this.admin.verifyKyc(id, status).subscribe({
      next: () => {
        this.notif.success('KYC mis a jour');
        this.loadUsers();
      },
    });
  }

  adjustTrustScore() {
    const user = this.selectedUser()?.user;
    if (!user) return;
    this.admin.adjustTrust(user.id, this.trustScore, this.trustReason).subscribe({
      next: () => {
        this.notif.success('Score de confiance ajuste');
        this.showTrustModal.set(false);
        this.loadUsers();
      },
    });
  }

  awardBadge() {
    const user = this.selectedUser()?.user;
    if (!user) return;
    this.admin.awardBadge(user.id, this.badgeType, this.badgeReason).subscribe({
      next: () => {
        this.notif.success('Badge attribue');
        this.showBadgeModal.set(false);
      },
    });
  }

  sendUserNotification() {
    const user = this.selectedUser()?.user;
    if (!user) return;
    this.admin.sendNotification(user.id, this.notifyTitle, this.notifyBody).subscribe({
      next: () => {
        this.notif.success('Notification envoyee');
        this.showNotifyModal.set(false);
        this.notifyTitle = '';
        this.notifyBody = '';
      },
    });
  }

  // ─── Moderation ────────────────────────────────────────────────────────
  loadModeration() {
    this.admin.getPendingModeration().subscribe({
      next: (res) => this.pendingVideos.set(res.data || []),
    });
  }

  moderateVideo(videoId: string, status: string) {
    this.admin.moderateVideo(videoId, status).subscribe({
      next: () => {
        this.pendingVideos.update(v => v.filter(video => video.id !== videoId));
        this.notif.success('Contenu modere');
      },
    });
  }

  toggleModerationSelect(id: string) {
    this.selectedModerationIds.update(ids =>
      ids.includes(id) ? ids.filter(i => i !== id) : [...ids, id]
    );
  }

  bulkApprove() {
    const ids = this.selectedModerationIds();
    if (!ids.length) return;
    this.admin.bulkModerate(ids, 'approved').subscribe({
      next: () => {
        this.pendingVideos.update(v => v.filter(video => !ids.includes(video.id)));
        this.selectedModerationIds.set([]);
        this.notif.success(`${ids.length} elements approuves`);
      },
    });
  }

  bulkReject() {
    const ids = this.selectedModerationIds();
    if (!ids.length) return;
    this.admin.bulkModerate(ids, 'rejected').subscribe({
      next: () => {
        this.pendingVideos.update(v => v.filter(video => !ids.includes(video.id)));
        this.selectedModerationIds.set([]);
        this.notif.success(`${ids.length} elements rejetes`);
      },
    });
  }

  // ─── Reports ───────────────────────────────────────────────────────────
  loadReports() {
    const days = this.reportPeriod();
    this.admin.getOverviewReport(days).subscribe({
      next: (res) => this.reportData.set(res),
    });
    this.admin.getTransactionReport(days).subscribe({
      next: (res) => this.transactionReport.set(res),
    });
    this.admin.getUserReport(days).subscribe({
      next: (res) => this.userReport.set(res),
    });
  }

  changeReportPeriod(days: number) {
    this.reportPeriod.set(days);
    this.loadReports();
  }

  // ─── Security ──────────────────────────────────────────────────────────
  loadSecurityLogs() {
    this.admin.getAuditLogs({ per_page: 50 }).subscribe({
      next: (res) => this.securityLogs.set(res.data || []),
    });
  }

  // ─── Helpers ───────────────────────────────────────────────────────────
  formatNumber(num: number): string {
    if (!num) return '0';
    if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
    return num.toString();
  }

  formatCurrency(amount: number): string {
    return new Intl.NumberFormat('fr-SN').format(amount || 0) + ' F';
  }

  getTrustColor(score: number): string {
    if (score >= 0.8) return 'var(--q-success)';
    if (score >= 0.5) return 'var(--q-warning)';
    return 'var(--q-danger)';
  }

  getStatusBadge(status: string): string {
    switch (status) {
      case 'active': return 'status-active';
      case 'suspended': return 'status-suspended';
      case 'pending': return 'status-pending';
      default: return '';
    }
  }

  goBack() { this.location.back(); }
}
