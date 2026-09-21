import { Component, ElementRef, EventEmitter, HostListener, Input, OnInit, Output, ViewChild, signal } from '@angular/core';

/**
 * Modale de réglage de la photo de couverture : l'utilisateur glisse
 * l'image pour la repositionner et utilise un curseur pour zoomer, avant
 * de valider un recadrage précis (au lieu d'envoyer l'image brute telle
 * quelle, ce qui produisait un cadrage aléatoire selon les proportions
 * d'origine de la photo).
 *
 * Le rendu final est toujours produit au ratio bannière 3:1 (comme sur
 * X/Twitter), quelle que soit la photo importée.
 */
@Component({
  selector: 'app-cover-cropper',
  standalone: true,
  imports: [],
  templateUrl: './cover-cropper.component.html',
  styleUrl: './cover-cropper.component.scss',
})
export class CoverCropperComponent implements OnInit {
  @Input({ required: true }) file!: File;
  @Output() cropped = new EventEmitter<Blob>();
  @Output() cancelled = new EventEmitter<void>();

  @ViewChild('frame') frameRef!: ElementRef<HTMLDivElement>;
  @ViewChild('img') imgRef!: ElementRef<HTMLImageElement>;

  readonly outputWidth = 1200;
  readonly outputHeight = 400;
  readonly maxZoom = 3;

  imageUrl = signal<string | null>(null);
  saving = signal(false);
  zoom = signal(1);

  private frameW = 0;
  private frameH = 0;
  private naturalW = 0;
  private naturalH = 0;
  private baseScale = 1;

  private translateX = 0;
  private translateY = 0;

  private dragging = false;
  private dragStartX = 0;
  private dragStartY = 0;
  private startTranslateX = 0;
  private startTranslateY = 0;

  ngOnInit(): void {
    const reader = new FileReader();
    reader.onload = () => this.imageUrl.set(reader.result as string);
    reader.readAsDataURL(this.file);
  }

  onImageLoad(): void {
    const frame = this.frameRef.nativeElement;
    const img = this.imgRef.nativeElement;
    this.frameW = frame.clientWidth;
    this.frameH = frame.clientHeight;
    this.naturalW = img.naturalWidth;
    this.naturalH = img.naturalHeight;

    this.baseScale = Math.max(this.frameW / this.naturalW, this.frameH / this.naturalH);
    this.zoom.set(1);

    const dispW = this.naturalW * this.currentScale();
    const dispH = this.naturalH * this.currentScale();
    this.translateX = (this.frameW - dispW) / 2;
    this.translateY = (this.frameH - dispH) / 2;
    this.applyTransform();
  }

  currentScale(): number {
    return this.baseScale * this.zoom();
  }

  onZoomChange(value: number): void {
    const oldScale = this.currentScale();
    this.zoom.set(value);
    const newScale = this.currentScale();
    const ratio = newScale / oldScale;

    const centerX = this.frameW / 2;
    const centerY = this.frameH / 2;
    this.translateX = centerX - (centerX - this.translateX) * ratio;
    this.translateY = centerY - (centerY - this.translateY) * ratio;

    this.clampTranslate();
    this.applyTransform();
  }

  onDragStart(event: MouseEvent | TouchEvent): void {
    this.dragging = true;
    const point = this.pointFromEvent(event);
    this.dragStartX = point.x;
    this.dragStartY = point.y;
    this.startTranslateX = this.translateX;
    this.startTranslateY = this.translateY;
    event.preventDefault();
  }

  @HostListener('window:mousemove', ['$event'])
  @HostListener('window:touchmove', ['$event'])
  onDragMove(event: MouseEvent | TouchEvent): void {
    if (!this.dragging) return;
    const point = this.pointFromEvent(event);
    this.translateX = this.startTranslateX + (point.x - this.dragStartX);
    this.translateY = this.startTranslateY + (point.y - this.dragStartY);
    this.clampTranslate();
    this.applyTransform();
  }

  @HostListener('window:mouseup')
  @HostListener('window:touchend')
  onDragEnd(): void {
    this.dragging = false;
  }

  private pointFromEvent(event: MouseEvent | TouchEvent): { x: number; y: number } {
    if ('touches' in event) {
      const t = event.touches[0] || event.changedTouches[0];
      return { x: t.clientX, y: t.clientY };
    }
    return { x: event.clientX, y: event.clientY };
  }

  private clampTranslate(): void {
    const dispW = this.naturalW * this.currentScale();
    const dispH = this.naturalH * this.currentScale();
    const minX = Math.min(0, this.frameW - dispW);
    const minY = Math.min(0, this.frameH - dispH);
    this.translateX = Math.min(0, Math.max(minX, this.translateX));
    this.translateY = Math.min(0, Math.max(minY, this.translateY));
  }

  private applyTransform(): void {
    if (!this.imgRef) return;
    this.imgRef.nativeElement.style.transform =
      `translate(${this.translateX}px, ${this.translateY}px) scale(${this.currentScale()})`;
  }

  cancel(): void {
    this.cancelled.emit();
  }

  confirm(): void {
    if (this.saving() || !this.frameW) return;
    this.saving.set(true);

    const canvas = document.createElement('canvas');
    canvas.width = this.outputWidth;
    canvas.height = this.outputHeight;
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      this.saving.set(false);
      return;
    }

    const canvasScale = this.outputWidth / this.frameW;

    ctx.drawImage(
      this.imgRef.nativeElement,
      this.translateX * canvasScale,
      this.translateY * canvasScale,
      this.naturalW * this.currentScale() * canvasScale,
      this.naturalH * this.currentScale() * canvasScale,
    );

    canvas.toBlob(
      (blob) => {
        this.saving.set(false);
        if (blob) this.cropped.emit(blob);
      },
      'image/jpeg',
      0.9,
    );
  }
}
