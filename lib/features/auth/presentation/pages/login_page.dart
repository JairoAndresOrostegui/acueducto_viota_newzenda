import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../controllers/auth_controller.dart';
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
                  AppColors.background,
                  AppColors.brandGreenSoft,
                  AppColors.brandBlueSoft,
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
                    child: SingleChildScrollView(
                      child: LoginSidePanel(
                        controller: controller,
                        isWide: isWide,
                      ),
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
