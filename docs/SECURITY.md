# Sécurité QUINCH

## Principes

1. Le backend est l'autorité de sécurité.
2. Le frontend ne doit jamais être considéré comme fiable.
3. Aucun secret fournisseur ne doit être envoyé à Angular.
4. Les opérations sensibles doivent être authentifiées, autorisées et journalisées.
5. Les uploads sont considérés comme hostiles.

## Authentification

- E-mail + mot de passe.
- Google OAuth avec validation du token côté backend.
- Récupération par code e-mail temporaire.
- Téléphone facultatif.
- Sanctum avec expiration configurée.

## Protection des routes

Les routes sensibles utilisent :

- `auth:sanctum` ;
- rôles ;
- permissions ;
- rate limiting ;
- policies ;
- middlewares de sécurité.

## Paiements

Le paiement est confirmé uniquement après vérification serveur :

```text
signature webhook
+ référence interne
+ montant
+ devise
+ état fournisseur
+ idempotence
```

## Uploads

À vérifier systématiquement :

- taille ;
- MIME réel ;
- extension ;
- propriétaire ;
- quota ;
- nom généré ;
- emplacement non exécutable ;
- nettoyage des fichiers abandonnés.

## Headers

Le projet prévoit notamment :

- CSP / CSP Report-Only ;
- HSTS ;
- X-Frame-Options ;
- Referrer-Policy ;
- Permissions-Policy.

La CSP doit être observée avant d'être rendue bloquante sur le domaine public.

## Secrets

Ne jamais committer :

- `.env` réel ;
- API keys ;
- webhook secrets ;
- mots de passe DB ;
- credentials OAuth ;
- credentials SMTP.

La CI utilise Gitleaks en complément des bonnes pratiques Git.

## Avant ouverture publique

- [ ] test OWASP manuel ;
- [ ] test des permissions/IDOR ;
- [ ] test upload ;
- [ ] test rate limiting ;
- [ ] test récupération compte ;
- [ ] test webhooks ;
- [ ] test logs ;
- [ ] test CSP ;
- [ ] test TLS ;
- [ ] `APP_DEBUG=false` ;
- [ ] secrets uniquement côté serveur.
