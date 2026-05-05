import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../catalogs/data/catalog_firestore_service.dart';
import '../../../catalogs/domain/catalog_item.dart';
import '../../data/user_admin_functions_service.dart';
import '../../data/user_firestore_service.dart';
import '../../domain/app_user.dart';

class UsersAdminPage extends StatefulWidget {
  const UsersAdminPage({
    super.key,
    required this.currentUser,
    this.userService,
    this.adminFunctionsService,
    this.documentTypeService,
    this.roleService,
    this.sectorService,
  });

  final AppUser currentUser;
  final UserFirestoreService? userService;
  final UserAdminFunctionsService? adminFunctionsService;
  final DocumentTypeCatalogService? documentTypeService;
  final RoleCatalogService? roleService;
  final SectorCatalogService? sectorService;

  @override
  State<UsersAdminPage> createState() => _UsersAdminPageState();
}

class _UsersAdminPageState extends State<UsersAdminPage> {
  static const int _pageSize = 10;

  late final UserFirestoreService _userService =
      widget.userService ?? UserFirestoreService();
  late final UserAdminFunctionsService _adminFunctionsService =
      widget.adminFunctionsService ?? UserAdminFunctionsService();
  late final DocumentTypeCatalogService _documentTypeService =
      widget.documentTypeService ?? DocumentTypeCatalogService();
  late final RoleCatalogService _roleService =
      widget.roleService ?? RoleCatalogService();
  late final SectorCatalogService _sectorService =
      widget.sectorService ?? SectorCatalogService();

  final TextEditingController _searchController = TextEditingController();
  final List<_PageCursor> _pageCursors = [const _PageCursor()];

  String _search = '';
  String _draftSearch = '';
  String _searchField = 'nombre';
  bool _isSaving = false;
  bool _isLoadingUsers = true;
  bool _isSearching = false;
  bool _isPendingView = false;
  String? _loadError;
  int _currentPageIndex = 0;
  bool _hasNextPage = false;
  int _activeCount = 0;
  int _clientCount = 0;
  int _pendingCount = 0;
  List<AppUser> _users = const [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadUserMetrics();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_loadError != null)
          _ErrorState(message: _loadError!)
        else if (_isLoadingUsers)
          const Center(child: CircularProgressIndicator())
        else
          AbsorbPointer(
            absorbing: _isSaving,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _UsersPageHeader(onCreate: () => _openForm()),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      label: _isSearching
                          ? 'Resultados encontrados'
                          : 'Usuarios en esta página',
                      value: '${_users.length}',
                      color: AppColors.brandBlueSoft,
                    ),
                    _MetricCard(
                      label: 'Activos',
                      value: '$_activeCount',
                      color: AppColors.brandGreenSoft,
                    ),
                    _MetricCard(
                      label: 'Clientes',
                      value: '$_clientCount',
                      color: AppColors.brandGreenSoft,
                    ),
                    _MetricCard(
                      label: 'Pendientes',
                      value:
                          '${_isPendingView ? _users.length : _pendingCount}',
                      color: AppColors.brandBlueSoft,
                      isSelected: _isPendingView,
                      onTap: _showPendingUsers,
                    ),
                  ],
                ),
                if (_isPendingView) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Usuarios pendientes por completar correo, cédula y celular.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _clearPendingView,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cerrar pendientes'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => _draftSearch = value.trim(),
                  onSubmitted: (_) => _applySearch(),
                  decoration: InputDecoration(
                    labelText: 'Buscar usuarios',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            onPressed: _clearSearch,
                            tooltip: 'Limpiar búsqueda',
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                _UserSearchFieldSelector(
                  selected: _searchField,
                  onChanged: (value) {
                    setState(() => _searchField = value);
                    if (_search.isNotEmpty) {
                      _loadUsers(pageIndex: 0);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _applySearch,
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Buscar'),
                    ),
                    if (_search.isNotEmpty || _draftSearch.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Limpiar'),
                      ),
                  ],
                ),
                if (_search.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Búsqueda aplicada: "$_search"',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: _users.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return _UserCard(
                              user: user,
                              canDelete:
                                  user.uid != widget.currentUser.uid &&
                                  user.rol != 'administrador',
                              onEdit: () => _openForm(user: user),
                              onDelete: () => _confirmDelete(user),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                _PaginationBar(
                  currentPage: _currentPageIndex + 1,
                  isSearching: _isSearching || _isPendingView,
                  hasPrevious:
                      !_isSearching && !_isPendingView && _currentPageIndex > 0,
                  hasNext: !_isSearching && !_isPendingView && _hasNextPage,
                  onPrevious: _previousPage,
                  onNext: _nextPage,
                ),
              ],
            ),
          ),
        if (_isSaving)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColoredBox(
                  color: AppColors.textPrimary.withValues(alpha: 0.18),
                  child: const Center(child: _SavingOverlay()),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadUsers({int? pageIndex}) async {
    final targetPage = pageIndex ?? _currentPageIndex;
    setState(() {
      _isLoadingUsers = true;
      _loadError = null;
    });

    try {
      if (_search.isNotEmpty) {
        final allUsers = await _userService.fetchAllUsers();
        final filtered = allUsers.where(_matchesSearch).toList();
        if (!mounted) {
          return;
        }
        setState(() {
          _isSearching = true;
          _isLoadingUsers = false;
          _users = filtered;
          _currentPageIndex = 0;
          _hasNextPage = false;
        });
        return;
      }

      final cursor = _pageCursors[targetPage].lastDocument;
      final page = await _userService.fetchUsersPage(
        limit: _pageSize,
        startAfter: cursor,
      );
      if (!mounted) {
        return;
      }

      if (_pageCursors.length > targetPage + 1) {
        _pageCursors.removeRange(targetPage + 1, _pageCursors.length);
      }
      if (page.hasMore) {
        _pageCursors.add(_PageCursor(lastDocument: page.lastDocument));
      }

      setState(() {
        _isSearching = false;
        _isLoadingUsers = false;
        _users = page.users;
        _currentPageIndex = targetPage;
        _hasNextPage = page.hasMore;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingUsers = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _loadUserMetrics() async {
    try {
      final allUsers = await _userService.fetchAllUsers();
      final activeCount = allUsers
          .where((user) => user.estado == 'activo')
          .length;
      final clientCount = allUsers
          .where((user) => user.rol == 'cliente')
          .length;
      final pendingCount = allUsers.where(_hasIncompleteProfile).length;
      if (!mounted) {
        return;
      }
      setState(() {
        _activeCount = activeCount;
        _clientCount = clientCount;
        _pendingCount = pendingCount;
      });
    } catch (_) {
      // The main user list already reports load errors; keep this badge passive.
    }
  }

  void _applySearch() {
    final normalized = _searchController.text.trim();
    _draftSearch = normalized;
    if (normalized == _search) {
      return;
    }
    setState(() {
      _search = normalized;
      _isPendingView = false;
    });
    _loadUsers(pageIndex: 0);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _search = '';
      _draftSearch = '';
      _isPendingView = false;
    });
    _loadUsers(pageIndex: 0);
  }

  Future<void> _showPendingUsers() async {
    if (_isLoadingUsers) {
      return;
    }
    setState(() {
      _isLoadingUsers = true;
      _loadError = null;
      _isPendingView = true;
      _isSearching = false;
      _search = '';
      _draftSearch = '';
    });
    _searchController.clear();

    try {
      final allUsers = await _userService.fetchAllUsers();
      final pendingUsers = allUsers.where(_hasIncompleteProfile).toList();
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingUsers = false;
        _users = pendingUsers;
        _pendingCount = pendingUsers.length;
        _activeCount = allUsers.where((user) => user.estado == 'activo').length;
        _clientCount = allUsers.where((user) => user.rol == 'cliente').length;
        _currentPageIndex = 0;
        _hasNextPage = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingUsers = false;
        _loadError = error.toString();
      });
    }
  }

  void _clearPendingView() {
    if (!_isPendingView) {
      return;
    }
    setState(() => _isPendingView = false);
    _loadUsers(pageIndex: 0);
  }

  Future<void> _nextPage() async {
    if (_isLoadingUsers || !_hasNextPage) {
      return;
    }
    await _loadUsers(pageIndex: _currentPageIndex + 1);
  }

  Future<void> _previousPage() async {
    if (_isLoadingUsers || _currentPageIndex == 0) {
      return;
    }
    await _loadUsers(pageIndex: _currentPageIndex - 1);
  }

  bool _matchesSearch(AppUser user) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }
    return switch (_searchField) {
      'correo' => user.correo.toLowerCase().contains(q),
      'rol' => user.rol.toLowerCase().contains(q),
      'tipoCliente' => user.tipoCliente.toLowerCase().contains(q),
      'documento' =>
        user.numeroDocumento.toLowerCase().contains(q) ||
            user.tipoDocumento.toLowerCase().contains(q),
      'estado' => user.estado.toLowerCase().contains(q),
      'codigoUsuario' =>
        user.codigosUsuario
            .map((item) => item.codigoUsuario)
            .join(' ')
            .toLowerCase()
            .contains(q),
      'contador' =>
        user.codigosUsuario
            .map((item) => item.numeroContador)
            .join(' ')
            .toLowerCase()
            .contains(q),
      'sector' =>
        user.codigosUsuario
            .map((item) => item.sector)
            .join(' ')
            .toLowerCase()
            .contains(q) ||
        user.sector.toLowerCase().contains(q),
      _ => user.nombre.toLowerCase().contains(q),
    };
  }

  bool _hasIncompleteProfile(AppUser user) {
    return user.rol == 'cliente' &&
        (_isMissingProfileValue(user.correo) ||
            _isMissingProfileValue(user.numeroDocumento) ||
            _isMissingProfileValue(user.numeroContacto));
  }

  bool _isMissingProfileValue(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty || normalized == 'na' || normalized == 'null';
  }

  Future<void> _openForm({AppUser? user}) async {
    try {
      final documentTypes = await _documentTypeService.fetchActiveItems();
      final roles = await _roleService.fetchActiveItems();
      final sectors = await _sectorService.fetchActiveItems();
      if (!mounted) {
        return;
      }

      final result = await showDialog<UserFormResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => UserFormDialog(
          user: user,
          documentTypes: documentTypes,
          roles: roles,
          sectors: sectors,
          allowEmptyFields: widget.currentUser.superAdmin,
        ),
      );

      if (result == null) {
        return;
      }

      setState(() => _isSaving = true);
      if (user == null) {
        await _adminFunctionsService.createManagedUser(
          user: result.user,
          password: result.password,
        );
      } else {
        await _adminFunctionsService.updateManagedUser(
          user: result.user,
          password: result.password,
        );
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user == null
                ? 'Usuario creado correctamente.'
                : 'Usuario actualizado correctamente.',
          ),
        ),
      );
      if (_isPendingView) {
        await _showPendingUsers();
      } else {
        await _loadUsers(pageIndex: _isSearching ? 0 : _currentPageIndex);
        await _loadUserMetrics();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = switch (error) {
        FirebaseFunctionsException _ =>
          error.message ?? error.details?.toString() ?? error.code,
        _ => error.toString(),
      };
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No fue posible guardar el usuario'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete(AppUser user) async {
    final confirmationController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canConfirm =
                confirmationController.text.trim().toUpperCase() == 'ELIMINAR';
            return AlertDialog(
              title: const Text('Eliminar usuario'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Se eliminara el perfil de ${toDisplayUserName(user.nombre)}.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Una vez eliminado, este usuario no podra ser recuperado.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmationController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Escribe ELIMINAR para confirmar',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: canConfirm
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: const Text('Eliminar'),
                ),
              ],
            );
          },
        );
      },
    );
    confirmationController.dispose();

    if (confirmed != true) {
      return;
    }

    try {
      await _adminFunctionsService.deleteManagedUser(user.uid);
      if (!mounted) {
        return;
      }
      if (_isPendingView) {
        await _showPendingUsers();
      } else {
        await _loadUsers(pageIndex: _isSearching ? 0 : _currentPageIndex);
        await _loadUserMetrics();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario eliminado correctamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible eliminar: $error')),
      );
    }
  }
}

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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
              ),
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
  })
    : codigoUsuarioController = TextEditingController(text: codigoUsuario),
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

class LegacyUsersHeader extends StatelessWidget {
  const LegacyUsersHeader({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final info = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Usuarios', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'CRUD administrativo con límite inicial de 200 registros para mantener la consulta controlada.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              info,
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Nuevo usuario'),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nuevo usuario'),
            ),
          ],
        );
      },
    );
  }
}

class _UsersPageHeader extends StatelessWidget {
  const _UsersPageHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final title = Text(
          'Usuarios',
          style: Theme.of(context).textTheme.headlineMedium,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onCreate,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Nuevo usuario'),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nuevo usuario'),
            ),
          ],
        );
      },
    );
  }
}

class _PageCursor {
  const _PageCursor({this.lastDocument});

  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.isSearching,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final bool isSearching;
  final bool hasPrevious;
  final bool hasNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    if (isSearching) {
      return Text(
        'La búsqueda recorre todos los usuarios y pausa la paginación mientras esté activa.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Text(
          'Página $currentPage',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: hasPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Anterior'),
            ),
            FilledButton.icon(
              onPressed: hasNext ? onNext : null,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Siguiente'),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserSearchFieldSelector extends StatelessWidget {
  const _UserSearchFieldSelector({
    required this.selected,
    required this.onChanged,
  });

  static const _options = [
    ('nombre', 'Nombre'),
    ('correo', 'Correo'),
    ('rol', 'Rol'),
    ('tipoCliente', 'Tipo cliente'),
    ('documento', 'Documento'),
    ('estado', 'Estado'),
    ('codigoUsuario', 'Codigo usuario'),
    ('contador', 'Contador'),
    ('sector', 'Sector'),
  ];

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final option in _options)
            InkWell(
              onTap: () => onChanged(option.$1),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Radio<String>(
                      value: option.$1,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(option.$2),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
    this.isSelected = false,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: AppColors.brandBlue, width: 2)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final AppUser user;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final info = Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.brandBlueSoft,
                foregroundColor: AppColors.brandBlueDark,
                child: Text(
                  toDisplayUserName(user.nombreCorto).characters.first,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toDisplayUserName(user.nombre),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userSummary(user),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
              if (canDelete)
                OutlinedButton.icon(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Eliminar'),
                ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                info,
                const SizedBox(height: 16),
                actions,
              ] else
                Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 12),
                    actions,
                  ],
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _InfoChip(label: 'Correo', value: user.correo),
                  _InfoChip(
                    label: 'Documento',
                    value:
                        '${toDisplayText(user.tipoDocumento)} ${user.numeroDocumento}',
                  ),
                  _InfoChip(label: 'Contacto', value: user.numeroContacto),
                  _InfoChip(
                    label: 'Tipo cliente',
                    value: user.tipoCliente == 'na'
                        ? 'NA'
                        : toDisplayText(user.tipoCliente),
                  ),
                  _InfoChip(
                    label: 'Código',
                    value: user.codigosUsuario.isEmpty
                        ? 'NA'
                        : user.codigosUsuario
                              .map((item) => item.codigoUsuario)
                              .join(', '),
                  ),
                  _InfoChip(
                    label: 'Contadores',
                    value: user.codigosUsuario.isEmpty
                        ? 'NA'
                        : user.codigosUsuario
                              .map(
                                (item) =>
                                    '${item.codigoUsuario} - ${item.numeroContador}',
                              )
                              .join(', '),
                  ),
                  _InfoChip(
                    label: 'Sector',
                    value: user.codigosUsuario.isEmpty
                        ? (user.sector == 'na' ? 'NA' : toDisplayText(user.sector))
                        : user.codigosUsuario
                              .map(
                                (item) =>
                                    '${item.codigoUsuario} - ${toDisplayText(item.sector)}',
                              )
                              .join(', '),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _userSummary(AppUser user) {
    if (user.tipoCliente == 'na') {
      return '${toDisplayText(user.rol)} · ${toDisplayText(user.estado)}';
    }
    return '${toDisplayText(user.rol)} ${toDisplayText(user.tipoCliente).toLowerCase()} · ${toDisplayText(user.estado)}';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: toDisplayText(value)),
          ],
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No hay usuarios que coincidan con el filtro actual.',
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No fue posible cargar usuarios.\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 36, height: 36, child: CircularProgressIndicator()),
          SizedBox(height: 16),
          Text('Guardando usuario...'),
        ],
      ),
    );
  }
}
