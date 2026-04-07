import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

class CachedAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final String name;
  final Color? borderColor;
  final double borderWidth;

  const CachedAvatar({
    super.key,
    this.url,
    required this.size,
    this.name = '?',
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(color: borderColor ?? AppColors.accent, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                placeholder: (_, __) => _Placeholder(size: size, name: name),
                errorWidget: (_, __, ___) => _Placeholder(size: size, name: name),
              )
            : _Placeholder(size: size, name: name),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double size;
  final String name;
  const _Placeholder({required this.size, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
