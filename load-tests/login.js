// Connexion par e-mail + mot de passe, à faible cadence : le hachage du mot de passe coûte du CPU
// volontairement, et les limiteurs (Laravel + nginx) bloquent au-delà de quelques essais par minute et par IP.
// Ce scénario vérifie le COÛT d'une connexion, pas la capacité à absorber une attaque.
import http from 'k6/http';
import { check } from 'k6';
import { API, JSON_HEADERS } from './lib.js';

const TOKENS = JSON.parse(open('./tokens.json'));
const PASSWORD = __ENV.LOAD_PASSWORD || 'LoadTest2026!x';

export const options = {
  scenarios: {
    login: { executor: 'constant-arrival-rate', rate: 3, timeUnit: '1m', duration: '3m', preAllocatedVUs: 2 },
  },
  thresholds: { http_req_failed: ['rate<0.05'], http_req_duration: ['p(95)<2000'] },
};

export default function () {
  const user = TOKENS[Math.floor(Math.random() * TOKENS.length)];
  const res = http.post(`${API}/auth/login`, JSON.stringify({ email: user.email, password: PASSWORD }), { headers: JSON_HEADERS });
  check(res, { 'connexion → 200': (r) => r.status === 200 });
}
