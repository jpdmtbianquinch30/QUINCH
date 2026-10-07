# QUINCH — mise à jour documentation/design — octobre 2026

## Documentation

- README racine réécrit comme documentation de référence.
- Architecture, API, sécurité, e-mail, paiements, exploitation, conformité et UI documentés.
- Les anciennes instructions utilisateur imposant un OTP SMS ont été retirées du guide public.
- Le modèle actuel est documenté : e-mail principal, téléphone facultatif, récupération par e-mail.
- Les paiements utilisateurs-à-utilisateurs sont explicitement hors périmètre.

## Design

- Nouveau système visuel QUINCH : bleu nuit + violet/indigo/bleu/cyan.
- Surfaces plus sobres et plus lisibles.
- Boutons, champs, cartes, modales et badges harmonisés.
- Touch targets renforcés sur mobile.
- Modales adaptées aux petits écrans.
- Respect de `prefers-reduced-motion`.
- Navigation Angular et routes conservées.
- Aucun service métier ou flux fonctionnel volontairement modifié par le redesign.
