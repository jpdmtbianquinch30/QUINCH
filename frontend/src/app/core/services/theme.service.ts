import { Injectable, signal, effect } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  private readonly STORAGE_KEY = 'quinch_theme';

  /** true = light mode, false = dark mode (default) */
  lightMode = signal(false);

  constructor() {
    // Restore from localStorage
    const saved = localStorage.getItem(this.STORAGE_KEY);
    if (saved === 'light') {
      this.lightMode.set(true);
    }

    // React to signal changes → apply body class + persist
    effect(() => {
      const isLight = this.lightMode();
      if (isLight) {
        document.body.classList.add('quinch-light');
        document.body.classList.remove('quinch-dark');
      } else {
        document.body.classList.remove('quinch-light');
        document.body.classList.add('quinch-dark');
      }
      localStorage.setItem(this.STORAGE_KEY, isLight ? 'light' : 'dark');
    });
  }

  toggle() {
    this.lightMode.set(!this.lightMode());
  }
}
