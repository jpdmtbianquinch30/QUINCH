// Utilitaires partagés par les scénarios k6 (voir docs/LOAD-TESTING.md).
import http from 'k6/http';
import { check } from 'k6';

// Adresse de l'API, SANS barre finale. Exemple : https://api-staging.quinch.sn/api/v1
export const API = (__ENV.API_URL || 'http://localhost:8080/api/v1').replace(/\/$/, '');
// Racine du serveur (pour /up).
export const ROOT = API.replace(/\/api\/v1$/, '');

export const JSON_HEADERS = { 'Content-Type': 'application/json', Accept: 'application/json' };

export function get(path, token, tags) {
  const headers = { Accept: 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  return http.get(`${API}${path}`, { headers, tags });
}

/** Vérifie un statut attendu et renvoie la réponse. */
export function expect(res, status, name) {
  check(res, { [`${name} → ${status}`]: (r) => r.status === status });
  return res;
}

/** Seuils communs : à adapter à vos objectifs avant de conclure « ça tient la charge ». */
export const COMMON_THRESHOLDS = {
  http_req_failed: ['rate<0.01'],      // moins de 1 % d'erreurs
  http_req_duration: ['p(95)<1000'],   // 95 % des réponses en moins d'1 s
};

/** Extrait la liste d'annonces d'une réponse paginée Laravel ({ data: [...] }). */
export function itemsOf(res) {
  try {
    const body = res.json();
    return Array.isArray(body) ? body : body.data || [];
  } catch (e) {
    return [];
  }
}
