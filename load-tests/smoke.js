// Test de fumée : 1 utilisateur virtuel, 30 s. À lancer AVANT tout test de charge :
// si celui-ci échoue, inutile de charger un système qui ne répond pas correctement.
import { sleep } from 'k6';
import http from 'k6/http';
import { API, ROOT, get, expect, COMMON_THRESHOLDS } from './lib.js';

export const options = {
  vus: 1,
  duration: '30s',
  thresholds: COMMON_THRESHOLDS,
};

export default function () {
  expect(http.get(`${ROOT}/up`), 200, 'up');
  expect(get('/categories'), 200, 'categories');
  expect(get('/products/feed'), 200, 'feed');
  expect(get('/legal/info'), 200, 'legal');
  expect(http.get(`${API}/auth/me`, { headers: { Accept: 'application/json' } }), 401, 'me sans jeton');
  sleep(1);
}
