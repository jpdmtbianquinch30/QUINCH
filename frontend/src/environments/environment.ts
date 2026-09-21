export const environment = {
  production: false,
  // Proxy: requests to /api/* are forwarded to http://127.0.0.1:8000 by Angular proxy
  apiUrl: '/api/v1',
  appName: 'QUINCH',
  // Client ID OAuth Google (console.cloud.google.com > Identifiants).
  // Laisser vide désactive proprement le bouton "Continuer avec Google".
  googleClientId: '',
  // SEC-05 : au-delà de cet âge (en minutes), AuthService rafraîchit le
  // jeton en tâche de fond. Volontairement bien en-dessous de
  // SANCTUM_TOKEN_EXPIRATION_MINUTES (14 jours) côté backend : les deux
  // valeurs sont indépendantes, celle-ci n'a besoin que d'être
  // confortablement plus courte. 7 jours ici.
  tokenRefreshThresholdMinutes: 10080,
};
