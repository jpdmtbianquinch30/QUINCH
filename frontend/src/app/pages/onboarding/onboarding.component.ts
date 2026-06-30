import { Component, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { ApiService } from '../../core/services/api.service';

interface OnboardingStep {
  title: string;
  subtitle: string;
  question: string | null;
  multiSelect: boolean;
  choices: { icon: string; label: string; value: string; description: string }[] | null;
}

@Component({
  selector: 'app-onboarding',
  standalone: true,
  templateUrl: './onboarding.component.html',
  styleUrl: './onboarding.component.scss',
})
export class OnboardingComponent {
  private router = inject(Router);
  private api = inject(ApiService);

  currentStep = signal(0);
  selectedCategories = signal<string[]>([]);
  selectedCity = signal('');
  animating = signal(false);

  steps: OnboardingStep[] = [
    {
      title: 'Bienvenue sur QUINCH !',
      subtitle: 'La nouvelle façon de shopper au Sénégal.\nAchetez et vendez en toute simplicité.',
      question: null,
      multiSelect: false,
      choices: null,
    },
    {
      title: 'Quelles catégories vous intéressent ?',
      subtitle: 'Personnalisez votre fil d\'actualité',
      question: 'categories',
      multiSelect: true,
      choices: [
        { icon: 'phone_iphone', label: 'Téléphones & Tech', value: 'electronics', description: '' },
        { icon: 'style', label: 'Mode & Accessoires', value: 'fashion', description: '' },
        { icon: 'home', label: 'Maison & Déco', value: 'home', description: '' },
        { icon: 'directions_car', label: 'Véhicules', value: 'vehicles', description: '' },
        { icon: 'sports_basketball', label: 'Sports & Loisirs', value: 'sports', description: '' },
        { icon: 'spa', label: 'Beauté & Santé', value: 'beauty', description: '' },
        { icon: 'kitchen', label: 'Électroménager', value: 'appliances', description: '' },
        { icon: 'handyman', label: 'Services', value: 'services', description: '' },
      ],
    },
    {
      title: 'Où vous trouvez-vous ?',
      subtitle: 'Pour des suggestions proches de chez vous',
      question: 'location',
      multiSelect: false,
      choices: [
        { icon: 'location_on', label: 'Dakar', value: 'Dakar', description: 'Capitale' },
        { icon: 'location_on', label: 'Saint-Louis', value: 'Saint-Louis', description: 'Nord' },
        { icon: 'location_on', label: 'Thiès', value: 'Thiès', description: 'Centre-Ouest' },
        { icon: 'location_on', label: 'Kaolack', value: 'Kaolack', description: 'Centre' },
        { icon: 'location_on', label: 'Ziguinchor', value: 'Ziguinchor', description: 'Sud' },
        { icon: 'location_on', label: 'Touba', value: 'Touba', description: 'Centre' },
        { icon: 'location_on', label: 'Mbour', value: 'Mbour', description: 'Petite Côte' },
        { icon: 'location_on', label: 'Autre', value: 'other', description: 'Autre ville' },
      ],
    },
  ];

  get step() { return this.steps[this.currentStep()]; }
  get progress() { return ((this.currentStep() + 1) / this.steps.length) * 100; }

  selectChoice(value: string) {
    const question = this.step.question;
    if (question === 'categories') {
      const current = this.selectedCategories();
      if (current.includes(value)) {
        this.selectedCategories.set(current.filter(c => c !== value));
      } else {
        this.selectedCategories.set([...current, value]);
      }
    } else if (question === 'location') {
      this.selectedCity.set(value);
      this.nextStep();
    }
  }

  isCategorySelected(value: string): boolean {
    return this.selectedCategories().includes(value);
  }

  isSelected(value: string): boolean {
    if (this.step.question === 'categories') return this.isCategorySelected(value);
    if (this.step.question === 'location') return this.selectedCity() === value;
    return false;
  }

  nextStep() {
    this.animating.set(true);
    setTimeout(() => {
      if (this.currentStep() < this.steps.length - 1) {
        this.currentStep.update(s => s + 1);
      } else {
        this.completeOnboarding();
      }
      this.animating.set(false);
    }, 300);
  }

  prevStep() {
    if (this.currentStep() > 0) {
      this.currentStep.update(s => s - 1);
    }
  }

  completeOnboarding() {
    this.api.post('user/preferences', {
      categories: this.selectedCategories(),
      location: { city: this.selectedCity(), region: this.selectedCity() },
    }).subscribe({
      next: () => this.router.navigate(['/feed']),
      error: () => this.router.navigate(['/feed']),
    });
  }
}
