import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/login_form.dart';
import '../widgets/login_side_panel.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF6FBFA),
                  Color(0xFFE6F4F1),
                  Color(0xFFE3F2F7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 32 : 18,
                      vertical: isWide ? 28 : 16,
                    ),
                    child: isWide
                        ? Row(
                            children: [
                              const Expanded(child: LoginSidePanel()),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _LoginCard(controller: controller),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: _LoginCard(controller: controller),
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                Icons.water_drop_rounded,
                color: AppColors.textOnDark,
                size: 30,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Ingreso al sistema',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Administra usuarios, recaudos, consumos y procesos del acueducto de las veredas Quitasol y Jazmin.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            LoginForm(controller: controller),
          ],
        ),
      ),
    );
  }
}
