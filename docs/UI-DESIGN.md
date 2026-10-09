# QUINCH — système visuel

## Direction

Le redesign conserve la navigation existante et les routes. Il adopte une identité plus sobre :

- fond bleu nuit/noir ;
- gradient violet → indigo → bleu/cyan ;
- surfaces légèrement vitrées ;
- bordures fines ;
- ombres douces ;
- typographie Inter ;
- accent vert réservé aux états métier/services existants ;
- contrastes renforcés ;
- grands touch targets sur mobile.

## Responsive

### Desktop

- sidebar fixe ;
- contenu fluide ;
- cartes avec largeur adaptable ;
- espaces généreux ;
- navigation inchangée.

### Mobile

- rail de navigation existant conservé ;
- largeur réduite ;
- labels courts ;
- boutons/touch targets d'au moins 44 px lorsque possible ;
- modales limitées à la largeur disponible ;
- champs à 16 px pour éviter le zoom iOS ;
- respect de `prefers-reduced-motion`.

## Règles

Ne pas ajouter des dégradés ou effets à chaque élément. Le gradient de marque doit rester une signature : logo, CTA principal, état actif ou élément Premium lorsque pertinent.

## Listes déroulantes (`<select>`)

Le menu d'un `<select>` est dessiné par le navigateur : il ignore les fonds translucides de nos champs et
s'affiche sur fond blanc. Une règle globale de `styles.scss` impose `color-scheme` (sombre ou clair selon le
thème) et un fond opaque (`--q-bg-elevated`) aux `<option>`. Ne pas utiliser de fond translucide sur une `<option>`.
