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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _clientCodeController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _contactNumberController = TextEditingController();

  bool _isClientLogin = true;
  bool _requiresProfileCompletion = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _clientCodeController.dispose();
    _documentNumberController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Stack(
          children: [
            AbsorbPointer(
              absorbing: widget.controller.isLoading,
              child: Form(
                key: _formKey,
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Administrativo'),
                    icon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Usuario'),
                    icon: Icon(Icons.person_outline_rounded),
                  ),
                ],
                selected: {_isClientLogin},
                onSelectionChanged: widget.controller.isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _isClientLogin = value.first;
                          _requiresProfileCompletion = false;
                        });
                        widget.controller.clearError();
                      },
              ),
              const SizedBox(height: 18),
              if (_isClientLogin) ...[
                _clientCodeField(),
                const SizedBox(height: 18),
                _emailField(required: _requiresProfileCompletion),
                if (_requiresProfileCompletion) ...[
                  const SizedBox(height: 18),
                  _documentNumberField(),
                  const SizedBox(height: 18),
                  _contactNumberField(),
                ],
              ] else ...[
                _emailField(required: true),
                const SizedBox(height: 18),
                _passwordField(),
              ],
              const SizedBox(height: 14),
              Center(
                child: CheckboxListTile(
                  value: widget.controller.rememberSession,
                  onChanged: widget.controller.isLoading
                      ? null
                      : (value) {
                          widget.controller.setRememberSession(value ?? false);
                        },
                  title: const Text(
                    'Mantener sesión activa en este equipo',
                    textAlign: TextAlign.center,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              if (widget.controller.errorMessage case final message?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
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
            ],
          ),
              ),
            ),
            if (widget.controller.isLoading)
              Positioned.fill(
                child: Container(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.72),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Cargando...'),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _emailField({required bool required}) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: _isClientLogin ? TextInputAction.done : TextInputAction.next,
      textAlign: TextAlign.center,
      onFieldSubmitted: _isClientLogin ? (_) => _submit() : null,
      decoration: InputDecoration(
        labelText: required ? 'Correo' : 'Correo (si ya lo tienes registrado)',
        hintText: 'Ingresa tu correo',
        prefixIcon: const Icon(Icons.alternate_email_rounded),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return required ? 'Ingresa el usuario de acceso.' : null;
        }
        if (!text.contains('@') || !text.contains('.')) {
          return 'Ingresa un correo válido.';
        }
        return null;
      },
      onChanged: (_) => widget.controller.clearError(),
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.center,
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
    );
  }

  Widget _clientCodeField() {
    return TextFormField(
      controller: _clientCodeController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.characters,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        labelText: 'Código usuario',
        hintText: 'Ingresa tu código de usuario',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return 'Ingresa el código de usuario.';
        }
        if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text)) {
          return 'Solo se permiten letras y números.';
        }
        return null;
      },
      onChanged: (_) => widget.controller.clearError(),
    );
  }

  Widget _documentNumberField() {
    return TextFormField(
      controller: _documentNumberController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      textAlign: TextAlign.center,
      decoration: const InputDecoration(
        labelText: 'Cédula',
        hintText: 'Ingresa tu número de documento',
        prefixIcon: Icon(Icons.badge_rounded),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return 'Ingresa tu cédula.';
        }
        if (!RegExp(r'^\d+$').hasMatch(text)) {
          return 'Solo se permiten números.';
        }
        return null;
      },
      onChanged: (_) => widget.controller.clearError(),
    );
  }

  Widget _contactNumberField() {
    return TextFormField(
      controller: _contactNumberController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      textAlign: TextAlign.center,
      onFieldSubmitted: (_) => _submit(),
      decoration: const InputDecoration(
        labelText: 'Celular',
        hintText: 'Ingresa tu número de contacto',
        prefixIcon: Icon(Icons.phone_outlined),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return 'Ingresa tu celular.';
        }
        if (!RegExp(r'^\d+$').hasMatch(text)) {
          return 'Solo se permiten números.';
        }
        return null;
      },
      onChanged: (_) => widget.controller.clearError(),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = _isClientLogin
        ? await _submitClientLogin()
        : await widget.controller.loginWithEmailAndPassword(
            email: _emailController.text,
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

  Future<bool> _submitClientLogin() async {
    final result = await widget.controller.loginWithClientCode(
      email: _emailController.text.trim().isEmpty ? null : _emailController.text,
      clientCode: _clientCodeController.text,
      documentNumber: _requiresProfileCompletion
          ? _documentNumberController.text
          : null,
      contactNumber:
          _requiresProfileCompletion ? _contactNumberController.text : null,
    );

    if (!mounted) {
      return false;
    }
    if (result.requiresProfileCompletion) {
      setState(() {
        _requiresProfileCompletion = true;
      });
      _formKey.currentState?.validate();
      return false;
    }
    return result.success;
  }
}
