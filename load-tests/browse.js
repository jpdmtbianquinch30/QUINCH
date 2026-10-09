// Navigation publique (visiteurs non connectés) : le trafic le plus fréquent.
//
//   k6 run -e API_URL=https://api-staging.quinch.sn/api/v1 load-tests/browse.js
//   k6 run -e PROFILE=stress ... load-tests/browse.js     (monte jusqu'à la casse)
import { sleep } from 'k6';
import { get, expect, itemsOf, COMMON_THRESHOLDS } from './lib.js';

const PROFILES = {
  // Charge réaliste de bêta : montée, palier, descente.
  load: [
    { duration: '1m', target: 20 },
    { duration: '3m', target: 20 },
    { duration: '1m', target: 0 },
  ],
  // Cherche la limite : on augmente jusqu'à voir les erreurs ou la latence exploser.
  stress: [
    { duration: '2m', target: 50 },
    { duration: '2m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '2m', target: 0 },
  ],
};

export const options = {
  stages: PROFILES[__ENV.PROFILE || 'load'],
  thresholds: COMMON_THRESHOLDS,
};

export function setup() {
  const feed = itemsOf(get('/products/feed?per_page=30'));
  return { slugs: feed.map((p) => p.slug).filter(Boolean) };
}

export default function (data) {
  const roll = Math.random();

  if (roll < 0.55) {
    expect(get('/products/feed?page=' + (1 + Math.floor(Math.random() * 3))), 200, 'feed');
  } else if (roll < 0.75) {
    expect(get('/products?page=' + (1 + Math.floor(Math.random() * 3))), 200, 'liste');
  } else if (roll < 0.85) {
    expect(get('/search?q=' + ['robe', 'telephone', 'sac', 'chaussures'][Math.floor(Math.random() * 4)]), 200, 'recherche');
  } else if (roll < 0.9) {
    expect(get('/categories'), 200, 'categories');
  } else if (data.slugs.length > 0) {
    const slug = data.slugs[Math.floor(Math.random() * data.slugs.length)];
    expect(get('/products/' + slug), 200, 'detail');
  }

  sleep(1 + Math.random() * 2); // un humain lit avant de cliquer
}
