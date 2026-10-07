// Applique le thème enregistré avant le rendu, pour éviter un flash.
// Fichier externe (et non un <script> inline) : la CSP de production n'autorise
// que les scripts du même domaine.
(function () {
  try {
    if (localStorage.getItem('quinch_theme') === 'light') {
      document.body.classList.add('quinch-light');
    }
  } catch (e) { /* stockage indisponible : thème sombre par défaut */ }
})();
