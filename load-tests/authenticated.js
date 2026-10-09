// Utilisateurs connectés. Les jetons sont créés à l'avance (aucune connexion pendant le test :
// les limiteurs de connexion fausseraient les mesures) :
//
//   docker compose exec app php artisan quinch:seed-load-users 100 --json > load-tests/tokens.json
//   k6 run -e API_URL=https://api-staging.quinch.sn/api/v1 load-tests/authenticated.js
import { sleep } from 'k6';
import { get, expect, COMMON_THRESHOLDS } from './lib.js';

const TOKENS = JSON.parse(open('./tokens.json'));

export const options = {
  stages: [
    { duration: '1m', target: 20 },
    { duration: '3m', target: 20 },
    { duration: '1m', target: 0 },
  ],
  thresholds: COMMON_THRESHOLDS,
};

export default function () {
  const token = TOKENS[(__VU - 1) % TOKENS.length].token;

  expect(get('/auth/me', token), 200, 'me');
  expect(get('/products/feed', token), 200, 'feed');
  expect(get('/notifications/unread-count', token), 200, 'notifications');
  expect(get('/conversations', token), 200, 'conversations');

  sleep(2 + Math.random() * 3);
}
