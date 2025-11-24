import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 120,
    this.showWordmark = true,
    this.subtitle,
  });

  final double size;
  final bool showWordmark;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceBlend = Color.lerp(
      colorScheme.surface,
      colorScheme.primaryContainer,
      0.2,
    );

    final logo = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surfaceBlend,
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.16),
            blurRadius: size * 0.08,
            offset: Offset(0, size * 0.04),
          ),
        ],
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.14),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.1),
        child: SvgPicture.asset(
          'img/icon.svg',
          width: size * 0.8,
          height: size * 0.8,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        if (showWordmark) ...[
          SizedBox(height: size * 0.12),
          Text(
            'Book Memoly',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ],
    );
  }
}
