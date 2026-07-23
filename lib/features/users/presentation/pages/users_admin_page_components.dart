part of 'users_admin_page.dart';

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({
    super.key,
    required this.documentTypes,
    required this.roles,
    required this.sectors,
    required this.allowEmptyFields,
    this.user,
  });

  final AppUser? user;
  final List<CatalogItem> documentTypes;
  final List<CatalogItem> roles;
  final List<CatalogItem> sectors;
  final bool allowEmptyFields;

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  static const List<String> _clientTypes = ['socio', 'suscriptor'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController = TextEditingController(
    text: widget.user == null ? '' : toDisplayUserName(widget.user!.nombre),
  );
  late final TextEditingController _numeroDocumentoController =
      TextEditingController(text: widget.user?.numeroDocumento ?? '');
  late final TextEditingController _numeroContactoController =
      TextEditingController(text: widget.user?.numeroContacto ?? '');
  late final List<_ClientCodeFormRow> _clientCodeRows =
      _initialClientCodeRows();
  late final TextEditingController _correoController = TextEditingController(
    text: widget.user?.correo ?? '',
  );
  late final TextEditingController _passwordController =
      TextEditingController();

  late String? _tipoDocumento = _initialDocumentType();
  late String? _rol = _initialRole();
  late String _tipoCliente = _initialClientType();
  late String _estado = widget.user?.estado ?? 'activo';
  late String? _sector = _initialSector();

  bool get _isEditing => widget.user != null;
  bool get _isClient => _rol == 'cliente';
  bool get _showLegacyClientFields => false;
  TextEditingController get _legacyRemovedCodigoUsuarioController =>
      _clientCodeRows.first.codigoUsuarioController;
  TextEditingController get _legacyRemovedNumeroContadorController =>
      _clientCodeRows.first.numeroContadorController;

  List<TextInputFormatter> get _codeInputFormatters => [
    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
  ];

  @override
  void initState() {
    super.initState();
    _syncRoleDependentFields();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _numeroDocumentoController.dispose();
    _numeroContactoController.dispose();
    for (final row in _clientCodeRows) {
      row.dispose();
    }
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = _fieldWidth(constraints.maxWidth);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing ? 'Editar usuario' : 'Nuevo usuario',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'El formulario usa catalogos activos de tipos de documento, roles y sectores.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _FieldBox(
                            width: width * 2 + 16,
                            child: _text(
                              _correoController,
                              'Correo',
                              validator: _emailValidator,
                            ),
                          ),
                          _FieldBox(
                            width: width * 2 + 16,
                            child: _text(_nombreController, 'Nombre completo'),
                          ),
                          _FieldBox(width: width, child: _selectDoc()),
                          _FieldBox(
                            width: width,
                            child: _text(
                              _numeroDocumentoController,
                              'Número documento',
                            ),
                          ),
                          _FieldBox(
                            width: width,
                            child: _text(
                              _numeroContactoController,
                              'Número contacto',
                            ),
                          ),
                          _FieldBox(width: width, child: _selectRole()),
                          _FieldBox(width: width, child: _selectClientType()),
                          _FieldBox(width: width, child: _selectState()),
                          if (!_isClient)
                            _FieldBox(
                              width: width * 2 + 16,
                              child: _password(),
                            ),
                          if (_showLegacyClientFields)
                            _FieldBox(
                              width: width,
                              child: _text(
                                _legacyRemovedCodigoUsuarioController,
                                'Código usuario',
                                enabled: _isClient,
                                validator: _isClient ? _codeRequired : null,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: _codeInputFormatters,
                              ),
                            ),
                          if (_showLegacyClientFields)
                            _FieldBox(
                              width: width,
                              child: _text(
                                _legacyRemovedNumeroContadorController,
                                'Código contador',
                                enabled: _isClient,
                                validator: _isClient
                                    ? _meterNumbersValidator
                                    : null,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: _codeInputFormatters,
                              ),
                            ),
                          _FieldBox(width: width, child: _selectSector()),
                        ],
                      ),
                      if (_isClient) ...[
                        const SizedBox(height: 18),
                        _clientCodesEditor(width),
                      ],
                      if (_isClient && widget.sectors.isEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Debes crear al menos un sector activo para registrar clientes.',
                        ),
                      ],
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            child: Text(
                              _isEditing ? 'Guardar cambios' : 'Crear usuario',
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(labelText: label),
      validator: validator ?? _required,
    );
  }

  Widget _clientCodesEditor(double fieldWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Códigos de usuario',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _addClientCodeRow,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar código'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._clientCodeRows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == _clientCodeRows.length - 1 ? 0 : 12,
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _FieldBox(
                  width: fieldWidth,
                  child: _text(
                    row.codigoUsuarioController,
                    'Código usuario',
                    validator: _codeRequired,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: _codeInputFormatters,
                  ),
                ),
                _FieldBox(
                  width: fieldWidth,
                  child: _text(
                    row.numeroContadorController,
                    'Código contador',
                    validator: _meterNumbersValidator,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: _codeInputFormatters,
                  ),
                ),
                _FieldBox(width: fieldWidth, child: _selectCodeSector(row)),
                IconButton.outlined(
                  onPressed: _clientCodeRows.length <= 1
                      ? null
                      : () => _removeClientCodeRow(index),
                  tooltip: 'Eliminar código',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _selectCodeSector(_ClientCodeFormRow row) {
    final sectorItems = [
      if (widget.allowEmptyFields)
        const DropdownMenuItem(value: 'na', child: Text('Sin sector')),
      ...widget.sectors.map(
        (item) => DropdownMenuItem(
          value: item.valor,
          child: Text(
            toDisplayText(item.nombre),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: row.sector,
      decoration: const InputDecoration(labelText: 'Sector del código'),
      items: sectorItems,
      onChanged: (value) => setState(() => row.sector = value ?? 'na'),
      validator: (value) {
        if (widget.allowEmptyFields) {
          return null;
        }
        if ((value ?? '').trim().isEmpty || value == 'na') {
          return 'Selecciona un sector.';
        }
        return null;
      },
    );
  }

  Widget _password() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      decoration: InputDecoration(
        labelText: _isEditing || _isClient
            ? 'Nueva clave (opcional)'
            : 'Clave temporal',
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (widget.allowEmptyFields && text.isEmpty) {
          return null;
        }
        if (!_isEditing && !_isClient && text.length < 8) {
          return 'La clave debe tener al menos 8 caracteres.';
        }
        if (text.isNotEmpty && text.length < 8) {
          return 'La clave debe tener al menos 8 caracteres.';
        }
        return null;
      },
    );
  }

  Widget _selectDoc() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _tipoDocumento,
      decoration: const InputDecoration(labelText: 'Tipo documento'),
      selectedItemBuilder: (_) => widget.documentTypes
          .map(
            (item) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                toDisplayText(item.valor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      items: widget.documentTypes
          .map(
            (item) => DropdownMenuItem(
              value: item.valor,
              child: Text(
                '${toDisplayText(item.valor)} - ${toDisplayText(item.nombre)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => _tipoDocumento = value),
      validator: (value) =>
          value == null ? 'Selecciona un tipo de documento.' : null,
    );
  }

  Widget _selectRole() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _rol,
      decoration: const InputDecoration(labelText: 'Rol'),
      selectedItemBuilder: (_) => widget.roles
          .map(
            (item) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                toDisplayText(item.nombre),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      items: widget.roles
          .map(
            (item) => DropdownMenuItem(
              value: item.valor,
              child: Text(
                toDisplayText(item.nombre),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() {
          _rol = value;
          _syncRoleDependentFields();
        });
      },
      validator: (value) => value == null ? 'Selecciona un rol.' : null,
    );
  }

  Widget _selectState() {
    return DropdownButtonFormField<String>(
      initialValue: _estado,
      decoration: const InputDecoration(labelText: 'Estado'),
      items: const [
        DropdownMenuItem(value: 'activo', child: Text('Activo')),
        DropdownMenuItem(value: 'inactivo', child: Text('Inactivo')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _estado = value);
        }
      },
    );
  }

  Widget _selectClientType() {
    return DropdownButtonFormField<String>(
      initialValue: _isClient ? _tipoCliente : 'na',
      decoration: const InputDecoration(labelText: 'Tipo cliente'),
      items: _isClient
          ? _clientTypes
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(toDisplayText(item)),
                  ),
                )
                .toList()
          : const [DropdownMenuItem(value: 'na', child: Text('NA'))],
      onChanged: _isClient
          ? (value) {
              if (value != null) {
                setState(() => _tipoCliente = value);
              }
            }
          : null,
      validator: (_) {
        if (!_isClient) {
          return null;
        }
        if (!_clientTypes.contains(_tipoCliente)) {
          return 'Selecciona un tipo de cliente.';
        }
        return null;
      },
    );
  }

  Widget _selectSector() {
    final sectorItems = [
      if (widget.allowEmptyFields)
        const DropdownMenuItem(value: 'na', child: Text('Sin sector')),
      ...widget.sectors.map(
        (item) => DropdownMenuItem(
          value: item.valor,
          child: Text(
            toDisplayText(item.nombre),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
    final selectedSectorItems = [
      if (widget.allowEmptyFields)
        const Align(alignment: Alignment.centerLeft, child: Text('Sin sector')),
      ...widget.sectors.map(
        (item) => Align(
          alignment: Alignment.centerLeft,
          child: Text(
            toDisplayText(item.nombre),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];

    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _isClient ? _sector : 'na',
      decoration: const InputDecoration(labelText: 'Sector'),
      selectedItemBuilder: (_) => _isClient
          ? selectedSectorItems
          : const [Align(alignment: Alignment.centerLeft, child: Text('NA'))],
      items: _isClient
          ? sectorItems
          : const [DropdownMenuItem(value: 'na', child: Text('NA'))],
      onChanged: _isClient ? (value) => setState(() => _sector = value) : null,
      validator: (_) {
        if (!_isClient) {
          return null;
        }
        if (widget.sectors.isEmpty) {
          return widget.allowEmptyFields ? null : 'No hay sectores activos.';
        }
        if ((_sector ?? '').trim().isEmpty) {
          return widget.allowEmptyFields ? null : 'Selecciona un sector.';
        }
        return null;
      },
    );
  }

  double _fieldWidth(double maxWidth) {
    if (maxWidth < 520) {
      return maxWidth;
    }
    if (maxWidth < 760) {
      return (maxWidth - 16) / 2;
    }
    return math.min((maxWidth - 32) / 3, 230);
  }

  String? _required(String? value) {
    if (widget.allowEmptyFields) {
      return null;
    }
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio.';
    }
    return null;
  }

  String? _codeRequired(String? value) {
    final base = _required(value);
    if (base != null) {
      return base;
    }
    final text = value?.trim() ?? '';
    if (widget.allowEmptyFields && text.isEmpty) {
      return null;
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text)) {
      return 'Solo se permiten letras y numeros.';
    }
    return null;
  }

  String? _meterNumbersValidator(String? value) {
    final base = _required(value);
    if (base != null) {
      return base;
    }
    final items = _parseMeterNumbers(value ?? '');
    if (items.isEmpty) {
      return widget.allowEmptyFields ? null : 'Ingresa el contador.';
    }
    if (items.any((item) => !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(item))) {
      return 'El contador debe contener solo letras y numeros.';
    }
    if (items.length != 1) {
      return 'Ingresa un solo contador.';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final base = _required(value);
    if (base != null) {
      return base;
    }
    final text = value?.trim() ?? '';
    if (widget.allowEmptyFields && text.isEmpty) {
      return null;
    }
    if (!text.contains('@') || !text.contains('.')) {
      return 'Correo inválido.';
    }
    return null;
  }

  String? _initialDocumentType() {
    if (widget.user != null &&
        widget.documentTypes.any(
          (item) => item.valor == widget.user!.tipoDocumento,
        )) {
      return widget.user!.tipoDocumento;
    }
    final preferred = widget.documentTypes.where((item) => item.valor == 'cc');
    if (preferred.isNotEmpty) {
      return preferred.first.valor;
    }
    return widget.documentTypes.isEmpty
        ? null
        : widget.documentTypes.first.valor;
  }

  String? _initialRole() {
    if (widget.user != null &&
        widget.roles.any((item) => item.valor == widget.user!.rol)) {
      return widget.user!.rol;
    }
    final preferred = widget.roles.where((item) => item.valor == 'cliente');
    if (preferred.isNotEmpty) {
      return preferred.first.valor;
    }
    return widget.roles.isEmpty ? null : widget.roles.first.valor;
  }

  String? _initialSector() {
    if (widget.allowEmptyFields &&
        (widget.user == null || widget.user!.sector == 'na')) {
      return 'na';
    }
    if (widget.user != null &&
        widget.user!.sector != 'na' &&
        widget.sectors.any((item) => item.valor == widget.user!.sector)) {
      return widget.user!.sector;
    }
    return widget.sectors.isEmpty ? null : widget.sectors.first.valor;
  }

  String _initialClientType() {
    if (widget.user != null &&
        _clientTypes.contains(widget.user!.tipoCliente)) {
      return widget.user!.tipoCliente;
    }
    return _clientTypes.first;
  }

  List<_ClientCodeFormRow> _initialClientCodeRows() {
    final existing = widget.user?.codigosUsuario ?? const <ClientUserCode>[];
    if (existing.isNotEmpty) {
      return existing.map(_ClientCodeFormRow.fromCode).toList();
    }
    return [_ClientCodeFormRow(sector: _sector ?? 'na')];
  }

  void _addClientCodeRow() {
    setState(
      () => _clientCodeRows.add(_ClientCodeFormRow(sector: _sector ?? 'na')),
    );
  }

  void _removeClientCodeRow(int index) {
    if (_clientCodeRows.length <= 1) {
      return;
    }
    final row = _clientCodeRows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  void _syncRoleDependentFields() {
    if (_isClient) {
      if (!_clientTypes.contains(_tipoCliente)) {
        _tipoCliente = _clientTypes.first;
      }
      _sector ??= widget.sectors.isEmpty ? null : widget.sectors.first.valor;
      return;
    }

    _tipoCliente = 'na';
    _sector = null;
  }

  void _submit() {
    if (widget.documentTypes.isEmpty || widget.roles.isEmpty) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final now = DateTime.now();
    final existing = widget.user;
    final clientCodes = _isClient
        ? _parseClientCodes()
        : const <ClientUserCode>[];
    final primaryCode = clientCodes.isEmpty
        ? 'na'
        : clientCodes.first.codigoUsuario;
    final meters = clientCodes.map((item) => item.numeroContador).toList();
    final user = AppUser(
      uid: existing?.uid ?? '',
      nombre: _nombreController.text.trim().toLowerCase(),
      tipoDocumento: _tipoDocumento!,
      numeroDocumento: _numeroDocumentoController.text.trim(),
      numeroContacto: _numeroContactoController.text.trim(),
      codigoUsuario: primaryCode,
      numeroContador: meters,
      codigosUsuario: clientCodes,
      rol: _rol!,
      tipoCliente: _isClient ? _tipoCliente : 'na',
      sector: _isClient ? (_sector ?? '') : 'na',
      correo: _correoController.text.trim().toLowerCase(),
      estado: _estado,
      superAdmin: existing?.superAdmin ?? false,
      fechaCreacion: existing?.fechaCreacion ?? now,
      fechaActualizacion: existing == null ? null : now,
    );

    Navigator.of(context).pop(
      UserFormResult(
        user: user,
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
      ),
    );
  }

  List<String> _parseMeterNumbers(String value) {
    return value
        .split(RegExp(r'[\s,;]+'))
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty && item.toLowerCase() != 'na')
        .toList();
  }

  List<ClientUserCode> _parseClientCodes() {
    return _clientCodeRows
        .map(
          (row) => ClientUserCode(
            codigoUsuario: row.codigoUsuarioController.text
                .trim()
                .toUpperCase(),
            numeroContador: row.numeroContadorController.text
                .trim()
                .toUpperCase(),
            sector: row.sector,
          ),
        )
        .where((item) => item.isValid)
        .toList();
  }
}

class _ClientCodeFormRow {
  _ClientCodeFormRow({
    String codigoUsuario = '',
    String numeroContador = '',
    this.sector = 'na',
  }) : codigoUsuarioController = TextEditingController(text: codigoUsuario),
       numeroContadorController = TextEditingController(text: numeroContador);

  factory _ClientCodeFormRow.fromCode(ClientUserCode code) {
    return _ClientCodeFormRow(
      codigoUsuario: code.codigoUsuario,
      numeroContador: code.numeroContador,
      sector: code.sector,
    );
  }

  final TextEditingController codigoUsuarioController;
  final TextEditingController numeroContadorController;
  String sector;

  void dispose() {
    codigoUsuarioController.dispose();
    numeroContadorController.dispose();
  }
}

class UserFormResult {
  const UserFormResult({required this.user, required this.password});

  final AppUser user;
  final String? password;
}
