#!/usr/bin/env bash
# Contrôles rapides après un déploiement (préproduction ou production) : le site répond, HTTPS et les
# en-têtes de sécurité sont en place, les routes protégées le sont.
#
# Usage :
#   ./scripts/staging-smoke-test.sh https://api-staging.quinch.sn https://staging.quinch.sn
#   HEALTH_TOKEN=... ./scripts/staging-smoke-test.sh <api> <app>      (ajoute le test de santé détaillé)
set -uo pipefail

API="${1:?Usage : $0 <url-api> <url-app>}"
APP="${2:?Usage : $0 <url-api> <url-app>}"
API="${API%/}"
APP="${APP%/}"

ok=0
ko=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $name"
    ok=$((ok + 1))
  else
    echo "  ✗ $name (attendu : $expected, obtenu : $actual)"
    ko=$((ko + 1))
  fi
}

status() { curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@"; }
has_header() { curl -sI --max-time 15 "$1" | tr -d '\r' | grep -qi "^$2:" && echo oui || echo non; }

echo "API : $API"
check "GET /up"                         200 "$(status "$API/up")"
check "GET /api/v1/categories"          200 "$(status "$API/api/v1/categories")"
check "GET /api/v1/products/feed"       200 "$(status "$API/api/v1/products/feed")"
check "GET /api/v1/legal/info"          200 "$(status "$API/api/v1/legal/info")"
check "GET /api/v1/auth/me sans jeton"  401 "$(status -H 'Accept: application/json' "$API/api/v1/auth/me")"
check "ops/health sans jeton caché"     404 "$(status -H 'Accept: application/json' "$API/api/v1/ops/health")"
check "Webhook Wave sans signature"     "refusé" "$(c=$(status -X POST -H 'Content-Type: application/json' -d '{}' "$API/api/v1/webhooks/wave"); [ "$c" -ge 400 ] && [ "$c" -lt 500 ] && echo refusé || echo "$c")"
check "API : en-tête CSP"               oui "$(has_header "$API/api/v1/categories" Content-Security-Policy)"
check "API : en-tête HSTS"              oui "$(has_header "$API/api/v1/categories" Strict-Transport-Security)"
check ".env non accessible"             "bloqué" "$(c=$(status "$API/.env"); [ "$c" = 403 ] || [ "$c" = 404 ] && echo bloqué || echo "$c")"

if [ -n "${HEALTH_TOKEN:-}" ]; then
  check "ops/health avec jeton" 200 "$(status -H "X-Health-Token: $HEALTH_TOKEN" -H 'Accept: application/json' "$API/api/v1/ops/health")"
fi

case "$API" in
  https://*)
    http_url="http://${API#https://}"
    code="$(status "$http_url/up")"
    check "HTTP redirige vers HTTPS" "redirigé" "$([ "$code" = 301 ] || [ "$code" = 308 ] && echo redirigé || echo "$code")"
    ;;
esac

echo "Application : $APP"
check "GET / (index.html)"              200 "$(status "$APP/")"
check "Route Angular /legal/cgu"        200 "$(status "$APP/legal/cgu")"
check "App : en-tête CSP"               oui "$(has_header "$APP/" Content-Security-Policy)"
check "App : X-Frame-Options"           oui "$(has_header "$APP/" X-Frame-Options)"

echo
echo "Résultat : $ok réussi(s), $ko échec(s)"
[ "$ko" -eq 0 ]
