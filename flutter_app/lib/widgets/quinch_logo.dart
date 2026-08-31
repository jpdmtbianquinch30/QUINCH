import 'package:flutter/material.dart';
import '../config/theme.dart';

class QuinchLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final double textSize;
  final Color? textColor;
  final bool withShadow;

  const QuinchLogo({
    super.key,
    this.size = 48,
    this.showText = false,
    this.textSize = 24,
    this.textColor,
    this.withShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.23),
        boxShadow: withShadow
            ? [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.06),
          ),
        ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.23),
        child: Image.asset(
          'assets/images/logo_quinch.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );

    if (!showText) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        SizedBox(width: size * 0.25),
        Text(
          'QUINCH',
          style: TextStyle(
            color: textColor ?? AppColors.textPrimary,
            fontSize: textSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

/// Branding complet — logo rond + QUINCH + tagline
/// Utilisé dans : login, register, onboarding, about
class QuinchBranding extends StatelessWidget {
  final double logoSize;
  final bool showTagline;
  final bool showFeatures;

  const QuinchBranding({
    super.key,
    this.logoSize = 80,
    this.showTagline = true,
    this.showFeatures = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QuinchLogo(size: logoSize, withShadow: true),
        const SizedBox(height: 16),
        Text(
          'QUINCH',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: logoSize * 0.42,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            'Investissons entre nous et chez nous',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: logoSize * 0.175,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (showFeatures) ...[
          const SizedBox(height: 32),
          const _Feature(
            icon: Icons.videocam_rounded,
            label: 'Vidéos produits immersives',
          ),
          const SizedBox(height: 12),
          const _Feature(
            icon: Icons.verified_user_rounded,
            label: 'Transactions sécurisées',
          ),
          const SizedBox(height: 12),
          const _Feature(
            icon: Icons.location_on_rounded,
            label: 'Marché local & proximité',
          ),
        ],
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accentLight, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}