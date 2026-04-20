import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import 'login_form.dart';

class LoginSidePanel extends StatelessWidget {
  const LoginSidePanel({
    super.key,
    required this.controller,
    required this.isWide,
  });

  final AuthController controller;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 980),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [AppColors.brandBlueDark, AppColors.brandGreenDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(isWide ? 36 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Acueducto Veredal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textOnDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Quitasol y Jazmin',
              textAlign: TextAlign.center,
              style: textTheme.displaySmall?.copyWith(
                color: AppColors.textOnDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Plataforma para la gesti\u00f3n del acueducto',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.brandBlueSoft,
              ),
            ),
            SizedBox(height: isWide ? 30 : 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isWide ? 28 : 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: const LinearGradient(
                          colors: [AppColors.brandBlue, AppColors.brandGreen],
                        ),
                      ),
                      child: const Icon(
                        Icons.people_alt_outlined,
                        color: AppColors.textOnDark,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Ingreso al sistema',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    LoginForm(controller: controller),
                  ],
                ),
              ),
            ),
            SizedBox(height: isWide ? 24 : 20),
            const _FeatureBadge(
              icon: Icons.water_drop_outlined,
              title: 'Consumo',
              subtitle: 'Lecturas y seguimiento del servicio',
            ),
          ],
        ),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.surface.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textOnDark),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.brandBlueSoft,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
