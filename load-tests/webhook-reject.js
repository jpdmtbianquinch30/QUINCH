// Webhook Wave sans signature valide : doit être refusé RAPIDEMENT (le serveur ne doit pas
// travailler pour un appelant qui ne connaît pas le secret). Mesure aussi le coût d'un flot de faux appels.
import http from 'k6/http';
import { check } from 'k6';
import { API, JSON_HEADERS } from './lib.js';

export const options = {
  vus: 10,
  duration: '30s',
  thresholds: { http_req_duration: ['p(95)<300'] },
};

export default function () {
  const res = http.post(
    `${API}/webhooks/wave`,
    JSON.stringify({ type: 'checkout.session.completed', data: { id: 'cos-fake', client_reference: 'premium:fake' } }),
    { headers: { ...JSON_HEADERS, 'Wave-Signature': 't=1,v1=invalide' } },
  );
  check(res, { 'webhook refusé (4xx)': (r) => r.status >= 400 && r.status < 500 });
}
