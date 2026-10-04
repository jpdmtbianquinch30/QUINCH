/** Petits utilitaires partagés par les pages admin. */
export const fmtMoney = (n: number | null | undefined) => new Intl.NumberFormat('fr-SN').format(Math.round(n || 0)) + ' F';
export const fmtNum = (n: number | null | undefined) => new Intl.NumberFormat('fr-SN').format(n || 0);

export function errMsg(e: any, fallback = 'Une erreur est survenue.'): string {
  const body = e?.error;
  if (body?.errors) {
    const first = Object.values(body.errors)[0] as any;
    return Array.isArray(first) ? first[0] : String(first);
  }
  return body?.message || fallback;
}

export function statusClass(status: string): string {
  switch (status) {
    case 'active': case 'approved': case 'resolved': case 'completed': case 'verified': case 'accepted': return 'ok';
    case 'pending': case 'flagged': case 'reviewed': case 'processing': case 'paused': return 'warn';
    case 'banned': case 'rejected': case 'disabled': case 'failed': case 'disputed': case 'suspended': case 'cancelled': return 'bad';
    default: return '';
  }
}

export const REASON_LABELS: Record<string, string> = {
  fraud: 'Fraude', inappropriate: 'Contenu inapproprié', counterfeit: 'Contrefaçon', spam: 'Spam', other: 'Autre',
  harassment: 'Harcèlement', inappropriate_content: 'Contenu inapproprié', impersonation: 'Usurpation',
};

export const ROLE_LABELS: Record<string, string> = {
  user: 'Utilisateur', moderator: 'Modérateur', admin: 'Administrateur', super_admin: 'Super admin',
};

export function mediaUrl(path: string | null | undefined): string {
  if (!path) return '';
  if (path.startsWith('http') || path.startsWith('/')) return path;
  return '/storage/' + path;
}
