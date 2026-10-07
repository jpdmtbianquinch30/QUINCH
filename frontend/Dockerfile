# syntax=docker/dockerfile:1
# Image de l'application Angular (production) : build puis service statique par
# nginx non privilégié (utilisateur non root, port 8080).
# Contexte de build : ./frontend (voir docker-compose.prod.yml).

# ─── Étape 1 : build ─────────────────────────────────────────────────────────
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . ./
RUN npx ng build --configuration production

# ─── Étape 2 : service statique ──────────────────────────────────────────────
FROM nginxinc/nginx-unprivileged:1.29-alpine
# Le modèle est traité au démarrage (envsubst) : ${API_ORIGIN} est injecté dans la CSP.
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist/frontend/browser /usr/share/nginx/html
# Valeurs par défaut (surchargées par docker-compose.prod.yml).
ENV API_ORIGIN="" \
    CSP_HEADER_NAME="Content-Security-Policy"
EXPOSE 8080
