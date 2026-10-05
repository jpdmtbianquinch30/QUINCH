import { registerLocaleData } from '@angular/common';
import localeFr from '@angular/common/locales/fr';
import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { App } from './app/app';

// Les gabarits utilisent number:'1.0-0':'fr-FR' (compteurs, prix). Sans cet
// enregistrement Angular lève NG0701 en plein rendu : c'était la cause des
// slides vidéo à moitié affichées (boutons / compteurs manquants).
registerLocaleData(localeFr, 'fr-FR');
registerLocaleData(localeFr, 'fr');

bootstrapApplication(App, appConfig)
  .catch((err) => console.error(err));
