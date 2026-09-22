export const environment = {
  production: true,
  apiUrl: 'https://api.quinch.sn/api/v1',
  appName: 'QUINCH',
  googleClientId: '604429121781-89lml03n917fh8t2athac0l4i5l0lob8.apps.googleusercontent.com',
  // SEC-05 : au-delà de cet âge (en minutes), AuthService rafraîchit le
  // jeton en tâche de fond. Volontairement bien en-dessous de
  // SANCTUM_TOKEN_EXPIRATION_MINUTES (14 jours) côté backend : les deux
  // valeurs sont indépendantes, celle-ci n'a besoin que d'être
  // confortablement plus courte. 7 jours ici.
  tokenRefreshThresholdMinutes: 10080,
};
