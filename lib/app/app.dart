import 'package:flutter/material.dart';

import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../theme/app_theme.dart';

class AcueductoViotaApp extends StatefulWidget {
  const AcueductoViotaApp({super.key});

  @override
  State<AcueductoViotaApp> createState() => _AcueductoViotaAppState();
}

class _AcueductoViotaAppState extends State<AcueductoViotaApp> {
  final AuthController _authController = AuthController();

  @override
  void dispose() {
    _authController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _authController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Acueducto Viota',
          theme: AppTheme.lightTheme,
          home: _authController.isAuthenticated
              ? HomePage(
                  userName: _authController.currentUserName,
                  onLogout: _authController.logout,
                )
              : LoginPage(controller: _authController),
        );
      },
    );
  }
}
