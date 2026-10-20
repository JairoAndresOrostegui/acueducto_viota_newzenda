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

part 'users_admin_page_components.dart';
part 'users_admin_page_widgets.dart';

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
                              canResetAccount:
                                  widget.currentUser.superAdmin &&
                                  user.rol == 'cliente',
                              onEdit: () => _openForm(user: user),
                              onResetAccount: () => _confirmResetAccount(user),
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

  Future<void> _confirmResetAccount(AppUser user) async {
    final confirmationController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canConfirm =
                confirmationController.text.trim().toUpperCase() == 'LIMPIAR';
            return AlertDialog(
              title: const Text('Limpiar datos de cuenta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Se limpiaran recibos, pagos, saldos, movimientos de cuenta y estados derivados de ${toDisplayUserName(user.nombre)}.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'El usuario y sus consumos registrados se conservaran. Los consumos quedaran como lecturas normales sin facturacion ni pago.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Esta accion es solo para pruebas y no se puede deshacer.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmationController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Escribe LIMPIAR para confirmar',
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
                  child: const Text('Limpiar'),
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

    setState(() => _isSaving = true);
    try {
      final summary = await _adminFunctionsService.resetClientAccountData(
        user.uid,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Limpieza finalizada: ${summary.deletedInvoices} recibos, ${summary.deletedMovements} movimientos y ${summary.resetConsumptions} consumos restablecidos.',
          ),
        ),
      );
      await _loadUsers(pageIndex: _isSearching ? 0 : _currentPageIndex);
      await _loadUserMetrics();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = switch (error) {
        FirebaseFunctionsException _ =>
          error.message ?? error.details?.toString() ?? error.code,
        _ => error.toString(),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No fue posible limpiar la cuenta: $message')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
