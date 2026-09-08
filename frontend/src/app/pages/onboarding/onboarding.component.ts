import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { ApiService } from '../../core/services/api.service';
import { ProductService } from '../../core/services/product.service';
import { AuthService } from '../../core/services/auth.service';
import { Category } from '../../core/models/product.model';

/**
 * Onboarding après inscription — adapté du design Flutter (OnboardingScreen) :
 * 3 étapes (bienvenue, centres d'intérêt, localisation), régions/villes du
 * Sénégal en cascade. Design (couleurs, composants) réadapté aux tokens
 * --q-* existants de l'app web plutôt que repris tel quel de Flutter, pour
 * rester cohérent avec le reste de QUINCH.
 */
@Component({
  selector: 'app-onboarding',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './onboarding.component.html',
  styleUrl: './onboarding.component.scss',
})
export class OnboardingComponent implements OnInit {
  private router = inject(Router);
  private api = inject(ApiService);
  private productService = inject(ProductService);
  auth = inject(AuthService);

  step = signal(0); // 0 = bienvenue, 1 = interets, 2 = localisation
  loading = signal(false);

  categories = signal<Category[]>([]);
  selectedCategories = signal<Set<string>>(new Set());
  selectedInterests = signal<Set<string>>(new Set());

  selectedRegion = signal('');
  selectedCity = signal('');

  totalSelected = computed(() => this.selectedCategories().size + this.selectedInterests().size);

  // ─── Régions -> villes du Sénégal ────────────────────────────────────────
  regionCities: Record<string, string[]> = {
    'Dakar': ['Dakar Plateau', 'Médina', 'Grand Dakar', 'Parcelles Assainies', 'Guédiawaye', 'Pikine', 'Rufisque', 'Bargny', 'Diamniadio', 'Sébikhotane', 'Keur Massar', 'Sangalkam', 'Yoff', 'Ngor', 'Ouakam', 'Mermoz', 'Almadies', 'Gorée'],
    'Thiès': ['Thiès', 'Mbour', 'Saly', 'Somone', 'Tivaouane', 'Joal-Fadiouth', 'Kayar', 'Pout', 'Mboro', 'Nguekhokh', 'Sindia', 'Popenguine', 'La Petite Côte'],
    'Diourbel': ['Diourbel', 'Touba', 'Mbacké', 'Bambey', 'Dinguiraye', 'Ndame', 'Lambaye'],
    'Saint-Louis': ['Saint-Louis', 'Richard-Toll', 'Dagana', 'Podor', 'Ross-Béthio', 'Gandon', 'Mpal', 'Thilogne'],
    'Kaolack': ['Kaolack', 'Nioro du Rip', 'Guinguinéo', 'Ndoffane', 'Keur Madiabel', 'Gandiaye', 'Sibassor'],
    'Fatick': ['Fatick', 'Foundiougne', 'Sokone', 'Gossas', 'Diofior', 'Passy', 'Toubacouta', 'Djilor'],
    'Ziguinchor': ['Ziguinchor', 'Bignona', 'Oussouye', 'Cap Skirring', 'Diouloulou', 'Thionk Essyl', 'Kafountine'],
    'Kolda': ['Kolda', 'Vélingara', 'Médina Yoro Foulah', 'Dabo', 'Salikégné', 'Kounkané'],
    'Tambacounda': ['Tambacounda', 'Bakel', 'Kidira', 'Goudiry', 'Koumpentoum', 'Missirah', 'Diankhe Makha'],
    'Kédougou': ['Kédougou', 'Saraya', 'Salémata', 'Bandafassi', 'Dindefelo', 'Fongolembi'],
    'Louga': ['Louga', 'Linguère', 'Kébémer', 'Dahra', 'Sakal', 'Coki', 'Ndande'],
    'Matam': ['Matam', 'Kanel', 'Ranérou', 'Ourossogui', 'Waoundé', 'Semme'],
    'Kaffrine': ['Kaffrine', 'Koungheul', 'Birkelane', 'Malem Hodar', 'Nganda', 'Diamagadio'],
    'Sédhiou': ['Sédhiou', 'Bounkiling', 'Goudomp', 'Marsassoum', 'Diattacounda', 'Tanaff'],
  };

  get regions(): string[] {
    return Object.keys(this.regionCities);
  }

  get availableCities(): string[] {
    return this.regionCities[this.selectedRegion()] || [];
  }

  // ─── Centres d'intérêt par défaut (en plus des catégories du backend) ────
  defaultInterests = [
    { id: 'electronics', name: 'Électronique & Tech', icon: 'devices' },
    { id: 'phones', name: 'Téléphones & Tablettes', icon: 'smartphone' },
    { id: 'fashion_men', name: 'Mode Homme', icon: 'checkroom' },
    { id: 'fashion_women', name: 'Mode Femme', icon: 'dry_cleaning' },
    { id: 'shoes', name: 'Chaussures', icon: 'ice_skating' },
    { id: 'bags', name: 'Sacs & Accessoires', icon: 'shopping_bag' },
    { id: 'beauty', name: 'Beauté & Cosmétiques', icon: 'face_retouching_natural' },
    { id: 'jewelry', name: 'Bijoux & Montres', icon: 'watch' },
    { id: 'home', name: 'Maison & Décoration', icon: 'home' },
    { id: 'furniture', name: 'Meubles', icon: 'chair' },
    { id: 'appliances', name: 'Électroménager', icon: 'kitchen' },
    { id: 'auto', name: 'Auto & Moto', icon: 'directions_car' },
    { id: 'sports', name: 'Sports & Loisirs', icon: 'sports_soccer' },
    { id: 'health', name: 'Santé & Bien-être', icon: 'health_and_safety' },
    { id: 'food', name: 'Alimentation & Boissons', icon: 'restaurant' },
    { id: 'books', name: 'Livres & Éducation', icon: 'menu_book' },
    { id: 'kids', name: 'Enfants & Bébés', icon: 'child_care' },
    { id: 'gaming', name: 'Jeux Vidéo & Consoles', icon: 'sports_esports' },
    { id: 'music', name: 'Musique & Instruments', icon: 'music_note' },
    { id: 'photo', name: 'Photo & Vidéo', icon: 'camera_alt' },
    { id: 'agriculture', name: 'Agriculture & Élevage', icon: 'grass' },
    { id: 'construction', name: 'BTP & Matériaux', icon: 'construction' },
    { id: 'services', name: 'Services & Freelance', icon: 'handyman' },
    { id: 'immobilier', name: 'Immobilier', icon: 'apartment' },
    { id: 'artisanat', name: 'Artisanat Local', icon: 'palette' },
    { id: 'textile', name: 'Tissus & Couture', icon: 'cut' },
    { id: 'event', name: 'Événementiel', icon: 'celebration' },
    { id: 'transport', name: 'Transport & Logistique', icon: 'local_shipping' },
  ];

  ngOnInit() {
    this.productService.getCategories().subscribe({
      next: (res) => this.categories.set(res.categories || []),
    });
  }

  toggleCategory(id: string) {
    const set = new Set(this.selectedCategories());
    set.has(id) ? set.delete(id) : set.add(id);
    this.selectedCategories.set(set);
  }

  toggleInterest(id: string) {
    const set = new Set(this.selectedInterests());
    set.has(id) ? set.delete(id) : set.add(id);
    this.selectedInterests.set(set);
  }

  isCategorySelected(id: string): boolean { return this.selectedCategories().has(id); }
  isInterestSelected(id: string): boolean { return this.selectedInterests().has(id); }

  chooseRegion(region: string) {
    this.selectedRegion.set(region);
    this.selectedCity.set(''); // reset la ville si on change de region
  }

  nextStep() {
    if (this.step() < 2) this.step.update(s => s + 1);
    else this.finish();
  }

  prevStep() {
    if (this.step() > 0) this.step.update(s => s - 1);
  }

  skip() {
    this.router.navigate(['/feed']);
  }

  finish() {
    this.loading.set(true);
    const categories = [...this.selectedCategories(), ...this.selectedInterests()];

    this.api.post<{ message: string; user: any }>('user/preferences', {
      categories,
      location: { city: this.selectedCity(), region: this.selectedRegion() },
    }).subscribe({
      next: (res) => {
        // Sans ce updateUser(), le signal AuthService.user() (lu par la
        // page profil et le reste de l'app) restait sur l'ancienne valeur
        // de city/region jusqu'à un rechargement complet de la page (seul
        // moment où getMe() est réappelé) : la ville/région choisie ici
        // semblait ne "jamais s'appliquer" au profil alors qu'elle était
        // bien enregistrée en base côté backend.
        if (res.user) this.auth.updateUser(res.user);
        this.loading.set(false);
        this.router.navigate(['/feed']);
      },
      error: () => { this.loading.set(false); this.router.navigate(['/feed']); },
    });
  }
}
