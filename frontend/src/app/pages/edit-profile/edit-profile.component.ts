import { Component, inject, OnInit, signal } from '@angular/core';
import { Router } from '@angular/router';
import { Location } from '@angular/common';
import { FormsModule, ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { AuthService } from '../../core/services/auth.service';
import { UserService } from '../../core/services/user.service';
import { NotificationService } from '../../core/services/notification.service';

@Component({
  selector: 'app-edit-profile',
  standalone: true,
  imports: [FormsModule, ReactiveFormsModule],
  templateUrl: './edit-profile.component.html',
  styleUrl: './edit-profile.component.scss',
})
export class EditProfileComponent implements OnInit {
  private fb = inject(FormBuilder);
  private router = inject(Router);
  private location = inject(Location);
  private auth = inject(AuthService);
  private userService = inject(UserService);
  private notify = inject(NotificationService);

  user = this.auth.user;

  profileForm!: FormGroup;
  saving = signal(false);
  uploadingAvatar = signal(false);
  uploadingCover = signal(false);

  avatarPreview = signal<string | null>(null);
  coverPreview = signal<string | null>(null);

  // Name change restriction (7 days minimum)
  canChangeName = signal(true);
  nameChangeCountdown = signal('');

  // ─── Régions -> villes du Sénégal ────────────────────────────────────────
  // Même mapping que onboarding.component.ts : avant ce fix, "cities" et
  // "regions" étaient deux listes plates indépendantes qui se chevauchaient
  // presque entièrement (ex: "Dakar" existait dans les deux), donc rien
  // n'empêchait de choisir "Dakar" comme ville ET "Dakar" comme région -
  // d'où l'affichage dupliqué "Dakar, Dakar" sur le profil.
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
    const region = this.profileForm?.get('region')?.value;
    return region ? (this.regionCities[region] || []) : [];
  }

  onRegionChange(): void {
    // La ville précédemment choisie n'a probablement aucun sens dans la
    // nouvelle région (ex: rester sur "Touba" après être passé de Diourbel
    // à Dakar) : on la réinitialise pour forcer un nouveau choix cohérent.
    this.profileForm.get('city')?.setValue('');
  }

  ngOnInit() {
    const u = this.user();
    this.profileForm = this.fb.group({
      full_name: [u?.full_name || '', [Validators.required, Validators.minLength(2), Validators.maxLength(50)]],
      username: [u?.username || '', [Validators.minLength(3), Validators.maxLength(30)]],
      email: [u?.email || '', [Validators.email]],
      city: [u?.city || ''],
      region: [u?.region || ''],
      bio: [u?.bio || ''],
    });
    this.avatarPreview.set(u?.avatar_url || null);
    this.coverPreview.set(u?.cover_url || null);

    // Check name change restriction (7 days)
    this.checkNameChangeRestriction();
  }

  private checkNameChangeRestriction() {
    const lastChange = localStorage.getItem('quinch_last_name_change');
    if (lastChange) {
      const lastDate = new Date(lastChange);
      const now = new Date();
      const diffDays = Math.floor((now.getTime() - lastDate.getTime()) / 86400000);
      if (diffDays < 7) {
        this.canChangeName.set(false);
        const remaining = 7 - diffDays;
        this.nameChangeCountdown.set(`Vous pourrez modifier votre nom dans ${remaining} jour(s)`);
        this.profileForm.get('full_name')?.disable();
      }
    }
  }

  // ─── Avatar Upload ──────────────────────────────
  onAvatarFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    if (file.size > 5 * 1024 * 1024) {
      this.notify.error('Image trop lourde (max 5 Mo).');
      return;
    }

    // Preview
    const reader = new FileReader();
    reader.onload = () => this.avatarPreview.set(reader.result as string);
    reader.readAsDataURL(file);

    this.uploadingAvatar.set(true);
    this.userService.uploadAvatar(file).subscribe({
      next: (res: any) => {
        this.uploadingAvatar.set(false);
        if (res.user) this.auth.updateUser(res.user);
        this.avatarPreview.set(res.avatar_url || res.user?.avatar_url);
        this.notify.success('Photo de profil mise a jour!');
      },
      error: () => {
        this.uploadingAvatar.set(false);
        this.notify.error('Erreur lors de l\'upload.');
      },
    });
    input.value = '';
  }

  // ─── Cover Upload ──────────────────────────────
  onCoverFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    if (file.size > 10 * 1024 * 1024) {
      this.notify.error('Image trop lourde (max 10 Mo).');
      return;
    }

    const reader = new FileReader();
    reader.onload = () => this.coverPreview.set(reader.result as string);
    reader.readAsDataURL(file);

    this.uploadingCover.set(true);
    this.userService.uploadCover(file).subscribe({
      next: (res: any) => {
        this.uploadingCover.set(false);
        if (res.user) this.auth.updateUser(res.user);
        this.coverPreview.set(res.cover_url || res.user?.cover_url);
        this.notify.success('Photo de couverture mise a jour!');
      },
      error: () => {
        this.uploadingCover.set(false);
        this.notify.error('Erreur lors de l\'upload.');
      },
    });
    input.value = '';
  }

  // ─── Save Profile ──────────────────────────────
  save(): void {
    if (this.profileForm.invalid || this.saving()) return;

    this.saving.set(true);
    const data = this.profileForm.value;

    // Remove empty string values
    const payload: Record<string, any> = {};
    for (const key of Object.keys(data)) {
      if (data[key] !== '' && data[key] !== null && data[key] !== undefined) {
        payload[key] = data[key];
      }
    }

    // Track name change date
    if (payload['full_name'] && payload['full_name'] !== this.user()?.full_name) {
      localStorage.setItem('quinch_last_name_change', new Date().toISOString());
    }

    this.userService.updateProfile(payload).subscribe({
      next: (res: any) => {
        this.saving.set(false);
        if (res.user) this.auth.updateUser(res.user);
        this.notify.success('Profil mis a jour!');
        this.router.navigate(['/profile']);
      },
      error: (err: any) => {
        this.saving.set(false);
        const msg = err?.error?.message || 'Erreur lors de la sauvegarde.';
        this.notify.error(msg);
      },
    });
  }

  cancel(): void {
    this.location.back();
  }
}
