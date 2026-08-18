import 'package:flutter/material.dart';

class ArrowsLogo extends StatelessWidget {
  const ArrowsLogo({super.key, this.size = 132});

  final double size;

  static const _assetPath = 'assets/images/app_logo.png';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4A3728).withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.24),
            child: Image.asset(
              _assetPath,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'ARROWS',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 5,
            height: 1,
            color: const Color(0xFF2E2118),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFB07B26).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'ARROW PUZZLE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 2.8,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A5A12),
            ),
          ),
        ),
      ],
    );
  }
}
