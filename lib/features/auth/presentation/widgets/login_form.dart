import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _identifierController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Correo institucional',
                  hintText: 'usuario@acueducto.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Ingresa el correo de acceso.';
                  }
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'Ingresa un correo valido.';
                  }
                  return null;
                },
                onChanged: (_) => widget.controller.clearError(),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Clave',
                  hintText: 'Ingresa tu clave',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                validator: (value) {
                  final text = value ?? '';
                  if (text.isEmpty) {
                    return 'Ingresa la clave.';
                  }
                  if (text.length < 8) {
                    return 'La clave debe tener al menos 8 caracteres.';
                  }
                  return null;
                },
                onChanged: (_) => widget.controller.clearError(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: widget.controller.rememberSession,
                          onChanged: widget.controller.isLoading
                              ? null
                              : (value) {
                                  widget.controller
                                      .setRememberSession(value ?? false);
                                },
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('Mantener sesion activa en este equipo'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.controller.errorMessage case final message?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCECEC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1CACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: widget.controller.isLoading ? null : _submit,
                child: widget.controller.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.textOnDark,
                        ),
                      )
                    : const Text('Ingresar'),
              ),
              const SizedBox(height: 14),
              Text(
                'Usa un usuario creado en Firebase Authentication para ingresar.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await widget.controller.login(
      identifier: _identifierController.text,
      password: _passwordController.text,
    );

    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bienvenido al sistema del acueducto.'),
      ),
    );
  }
}
