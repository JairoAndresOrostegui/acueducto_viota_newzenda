import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class LoginSidePanel extends StatelessWidget {
  const LoginSidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [AppColors.brandBlueDark, AppColors.brandGreenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Acueducto Veredal',
                  style: TextStyle(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Quitasol y Jazmin',
                style: textTheme.displaySmall?.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Plataforma de gestion para el acueducto del municipio de Viota, Cundinamarca.',
                style: textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFD9EFF3),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: const [
              _FeatureBadge(
                icon: Icons.people_alt_outlined,
                title: 'Usuarios',
                subtitle: 'Control de suscriptores y roles',
              ),
              _FeatureBadge(
                icon: Icons.receipt_long_outlined,
                title: 'Recaudo',
                subtitle: 'Facturacion y pagos organizados',
              ),
              _FeatureBadge(
                icon: Icons.water_drop_outlined,
                title: 'Consumo',
                subtitle: 'Lecturas y seguimiento del servicio',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  const _FeatureBadge({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textOnDark),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textOnDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFFD9EFF3), height: 1.35),
          ),
        ],
      ),
    );
  }
}
