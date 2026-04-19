import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../../catalogs/data/catalog_firestore_service.dart';
import '../../../catalogs/domain/catalog_item.dart';
import '../../data/user_admin_functions_service.dart';
import '../../data/user_firestore_service.dart';
import '../../domain/app_user.dart';

class UsersAdminPage extends StatefulWidget {
  const UsersAdminPage({super.key, required this.currentUser, this.userService, this.adminFunctionsService, this.documentTypeService, this.roleService, this.sectorService});
  final AppUser currentUser;
  final UserFirestoreService? userService;
  final UserAdminFunctionsService? adminFunctionsService;
  final DocumentTypeCatalogService? documentTypeService;
  final RoleCatalogService? roleService;
  final SectorCatalogService? sectorService;
  @override State<UsersAdminPage> createState() => _UsersAdminPageState();
}

class _UsersAdminPageState extends State<UsersAdminPage> {
  static const int _userLimit = 200;
  late final UserFirestoreService _userService = widget.userService ?? UserFirestoreService();
  late final UserAdminFunctionsService _adminFunctionsService = widget.adminFunctionsService ?? UserAdminFunctionsService();
  late final DocumentTypeCatalogService _documentTypeService = widget.documentTypeService ?? DocumentTypeCatalogService();
  late final RoleCatalogService _roleService = widget.roleService ?? RoleCatalogService();
  late final SectorCatalogService _sectorService = widget.sectorService ?? SectorCatalogService();
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _userService.watchUsers(limit: _userLimit),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ErrorState(message: snapshot.error.toString());
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapshot.data!;
        final filtered = users.where(_matchesSearch).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Header(onCreate: () => _openForm()),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _MetricCard(label: 'Usuarios cargados', value: '${users.length}', color: AppColors.brandBlueSoft),
            _MetricCard(label: 'Activos', value: '${users.where((u) => u.estado == 'activo').length}', color: AppColors.brandGreenSoft),
            _MetricCard(label: 'Clientes', value: '${users.where((u) => u.rol == 'cliente').length}', color: const Color(0xFFE6F6ED)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: const InputDecoration(labelText: 'Buscar por nombre, correo, rol, documento o estado', prefixIcon: Icon(Icons.search_rounded)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      return _UserCard(
                        user: user,
                        canDelete: user.uid != widget.currentUser.uid,
                        onEdit: () => _openForm(user: user),
                        onDelete: () => _confirmDelete(user),
                      );
                    },
                  ),
          ),
        ]);
      },
    );
  }

  bool _matchesSearch(AppUser user) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    return user.nombre.toLowerCase().contains(q) || user.correo.toLowerCase().contains(q) || user.rol.toLowerCase().contains(q) || user.estado.toLowerCase().contains(q) || user.numeroDocumento.toLowerCase().contains(q) || user.tipoDocumento.toLowerCase().contains(q) || user.sector.toLowerCase().contains(q);
  }

  Future<void> _openForm({AppUser? user}) async {
    try {
      final documentTypes = await _documentTypeService.fetchActiveItems();
      final roles = await _roleService.fetchActiveItems();
      final sectors = await _sectorService.fetchActiveItems();
      if (!mounted) return;
      final result = await showDialog<UserFormResult>(
        context: context,
        barrierDismissible: false,
        builder: (context) => UserFormDialog(
          user: user,
          documentTypes: documentTypes,
          roles: roles,
          sectors: sectors,
        ),
      );
      if (result == null) return;
      if (user == null) {
        await _adminFunctionsService.createManagedUser(user: result.user, password: result.password!);
      } else {
        await _adminFunctionsService.updateManagedUser(user: result.user, password: result.password);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(user == null ? 'Usuario creado correctamente.' : 'Usuario actualizado correctamente.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible guardar: $error')));
    }
  }

  Future<void> _confirmDelete(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('Se eliminara el perfil de ${toDisplayText(user.nombre)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _adminFunctionsService.deleteManagedUser(user.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario eliminado correctamente.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No fue posible eliminar: $error')));
    }
  }
}

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key, required this.documentTypes, required this.roles, required this.sectors, this.user});
  final AppUser? user;
  final List<CatalogItem> documentTypes;
  final List<CatalogItem> roles;
  final List<CatalogItem> sectors;
  @override State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController = TextEditingController(text: widget.user == null ? '' : toDisplayText(widget.user!.nombre));
  late final TextEditingController _numeroDocumentoController = TextEditingController(text: widget.user?.numeroDocumento ?? '');
  late final TextEditingController _numeroContactoController = TextEditingController(text: widget.user?.numeroContacto ?? '');
  late final TextEditingController _codigoUsuarioController = TextEditingController(text: widget.user?.codigoUsuario == 'na' ? '' : widget.user?.codigoUsuario ?? '');
  late final TextEditingController _numeroContadorController = TextEditingController(text: widget.user?.numeroContador == 'na' ? '' : widget.user?.numeroContador ?? '');
  late final TextEditingController _correoController = TextEditingController(text: widget.user?.correo ?? '');
  late final TextEditingController _passwordController = TextEditingController();
  late String? _tipoDocumento = _initialDocumentType();
  late String? _rol = _initialRole();
  late String _estado = widget.user?.estado ?? 'activo';
  late String? _sector = _initialSector();
  bool get _isEditing => widget.user != null;
  bool get _isClient => _rol == 'cliente';

  @override
  void dispose() {
    _nombreController.dispose();
    _numeroDocumentoController.dispose();
    _numeroContactoController.dispose();
    _codigoUsuarioController.dispose();
    _numeroContadorController.dispose();
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
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_isEditing ? 'Editar usuario' : 'Nuevo usuario', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text('El formulario usa catalogos activos de tipos de documento, roles y sectores.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    Wrap(spacing: 16, runSpacing: 16, children: [
                      _FieldBox(width: width * 2 + 16, child: _text(_correoController, 'Correo', validator: _emailValidator)),
                      _FieldBox(width: width * 2 + 16, child: _text(_nombreController, 'Nombre completo')),
                      _FieldBox(width: width, child: _selectDoc()),
                      _FieldBox(width: width, child: _text(_numeroDocumentoController, 'Numero documento')),
                      _FieldBox(width: width, child: _text(_numeroContactoController, 'Numero contacto')),
                      _FieldBox(width: width, child: _selectRole()),
                      _FieldBox(width: width, child: _selectState()),
                      _FieldBox(width: width * 2 + 16, child: _password()),
                      _FieldBox(width: width, child: _text(_codigoUsuarioController, 'Codigo usuario', enabled: _isClient, validator: _isClient ? _required : null)),
                      _FieldBox(width: width, child: _text(_numeroContadorController, 'Numero contador', enabled: _isClient, validator: _isClient ? _required : null)),
                      _FieldBox(width: width, child: _selectSector()),
                    ]),
                    if (_isClient && widget.sectors.isEmpty) ...[const SizedBox(height: 12), const Text('Debes crear al menos un sector activo para registrar clientes.')],
                    const SizedBox(height: 24),
                    Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 12, children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                      ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(_isEditing ? 'Guardar cambios' : 'Crear usuario')),
                    ]),
                  ]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _text(TextEditingController controller, String label, {bool enabled = true, String? Function(String?)? validator}) {
    return TextFormField(controller: controller, enabled: enabled, decoration: InputDecoration(labelText: label), validator: validator ?? _required);
  }

  Widget _password() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      decoration: InputDecoration(labelText: _isEditing ? 'Nueva clave (opcional)' : 'Clave temporal'),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (!_isEditing && text.length < 8) return 'La clave debe tener al menos 8 caracteres.';
        if (_isEditing && text.isNotEmpty && text.length < 8) return 'La clave debe tener al menos 8 caracteres.';
        return null;
      },
    );
  }

  Widget _selectDoc() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _tipoDocumento,
      decoration: const InputDecoration(labelText: 'Tipo documento'),
      selectedItemBuilder: (_) => widget.documentTypes.map((item) => Align(alignment: Alignment.centerLeft, child: Text(toDisplayText(item.valor), overflow: TextOverflow.ellipsis))).toList(),
      items: widget.documentTypes.map((item) => DropdownMenuItem(value: item.valor, child: Text('${toDisplayText(item.valor)} - ${toDisplayText(item.nombre)}', overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (value) => setState(() => _tipoDocumento = value),
      validator: (value) => value == null ? 'Selecciona un tipo de documento.' : null,
    );
  }

  Widget _selectRole() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _rol,
      decoration: const InputDecoration(labelText: 'Rol'),
      selectedItemBuilder: (_) => widget.roles.map((item) => Align(alignment: Alignment.centerLeft, child: Text(toDisplayText(item.nombre), overflow: TextOverflow.ellipsis))).toList(),
      items: widget.roles.map((item) => DropdownMenuItem(value: item.valor, child: Text(toDisplayText(item.nombre), overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _rol = value;
          if (_isClient) {
            _sector ??= widget.sectors.isEmpty ? null : widget.sectors.first.valor;
          } else {
            _codigoUsuarioController.text = '';
            _numeroContadorController.text = '';
            _sector = null;
          }
        });
      },
      validator: (value) => value == null ? 'Selecciona un rol.' : null,
    );
  }

  Widget _selectState() {
    return DropdownButtonFormField<String>(
      initialValue: _estado,
      decoration: const InputDecoration(labelText: 'Estado'),
      items: const [DropdownMenuItem(value: 'activo', child: Text('Activo')), DropdownMenuItem(value: 'inactivo', child: Text('Inactivo'))],
      onChanged: (value) { if (value != null) setState(() => _estado = value); },
    );
  }

  Widget _selectSector() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _isClient ? _sector : 'na',
      decoration: const InputDecoration(labelText: 'Sector'),
      selectedItemBuilder: (_) => _isClient
          ? widget.sectors.map((item) => Align(alignment: Alignment.centerLeft, child: Text(toDisplayText(item.nombre), overflow: TextOverflow.ellipsis))).toList()
          : const [Align(alignment: Alignment.centerLeft, child: Text('NA'))],
      items: _isClient
          ? widget.sectors.map((item) => DropdownMenuItem(value: item.valor, child: Text(toDisplayText(item.nombre), overflow: TextOverflow.ellipsis))).toList()
          : const [DropdownMenuItem(value: 'na', child: Text('NA'))],
      onChanged: _isClient ? (value) => setState(() => _sector = value) : null,
      validator: (_) {
        if (!_isClient) return null;
        if (widget.sectors.isEmpty) return 'No hay sectores activos.';
        if ((_sector ?? '').trim().isEmpty) return 'Selecciona un sector.';
        return null;
      },
    );
  }

  double _fieldWidth(double maxWidth) {
    if (maxWidth < 520) return maxWidth;
    if (maxWidth < 760) return (maxWidth - 16) / 2;
    return math.min((maxWidth - 32) / 3, 230);
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo obligatorio.' : null;
  String? _emailValidator(String? value) {
    final base = _required(value);
    if (base != null) return base;
    final text = value!.trim();
    if (!text.contains('@') || !text.contains('.')) return 'Correo invalido.';
    return null;
  }

  String? _initialDocumentType() {
    if (widget.user != null && widget.documentTypes.any((item) => item.valor == widget.user!.tipoDocumento)) return widget.user!.tipoDocumento;
    final preferred = widget.documentTypes.where((item) => item.valor == 'cc');
    if (preferred.isNotEmpty) return preferred.first.valor;
    return widget.documentTypes.isEmpty ? null : widget.documentTypes.first.valor;
  }

  String? _initialRole() {
    if (widget.user != null && widget.roles.any((item) => item.valor == widget.user!.rol)) return widget.user!.rol;
    final preferred = widget.roles.where((item) => item.valor == 'cliente');
    if (preferred.isNotEmpty) return preferred.first.valor;
    return widget.roles.isEmpty ? null : widget.roles.first.valor;
  }

  String? _initialSector() {
    if (widget.user != null && widget.user!.sector != 'na' && widget.sectors.any((item) => item.valor == widget.user!.sector)) return widget.user!.sector;
    return widget.sectors.isEmpty ? null : widget.sectors.first.valor;
  }

  void _submit() {
    if (widget.documentTypes.isEmpty || widget.roles.isEmpty) return;
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final existing = widget.user;
    final user = AppUser(
      uid: existing?.uid ?? '',
      nombre: _nombreController.text.trim().toLowerCase(),
      tipoDocumento: _tipoDocumento!,
      numeroDocumento: _numeroDocumentoController.text.trim(),
      numeroContacto: _numeroContactoController.text.trim(),
      codigoUsuario: _isClient ? _codigoUsuarioController.text.trim() : 'na',
      numeroContador: _isClient ? _numeroContadorController.text.trim() : 'na',
      rol: _rol!,
      sector: _isClient ? (_sector ?? '') : 'na',
      correo: _correoController.text.trim().toLowerCase(),
      estado: _estado,
      fechaCreacion: existing?.fechaCreacion ?? now,
      fechaActualizacion: existing == null ? null : now,
    );
    Navigator.of(context).pop(UserFormResult(user: user, password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim()));
  }
}

class UserFormResult {
  const UserFormResult({required this.user, required this.password});
  final AppUser user;
  final String? password;
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Usuarios', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('CRUD administrativo con limite inicial de 200 registros para mantener la consulta controlada.', style: Theme.of(context).textTheme.bodyLarge),
      ]);
      if (compact) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 16), ElevatedButton.icon(onPressed: onCreate, style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Nuevo usuario'))]);
      }
      return Row(children: [Expanded(child: info), const SizedBox(width: 16), ElevatedButton.icon(onPressed: onCreate, style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Nuevo usuario'))]);
    });
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(width: 220, padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 8), Text(value, style: Theme.of(context).textTheme.headlineMedium)]));
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.canDelete, required this.onEdit, required this.onDelete});
  final AppUser user;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE0ECE8))),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final info = Row(children: [
          CircleAvatar(backgroundColor: AppColors.brandBlueSoft, foregroundColor: AppColors.brandBlueDark, child: Text(toDisplayText(user.nombreCorto).characters.first)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(toDisplayText(user.nombre), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${toDisplayText(user.rol)} · ${toDisplayText(user.estado)}', style: Theme.of(context).textTheme.bodyMedium),
          ])),
        ]);
        final actions = Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: onEdit, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), icon: const Icon(Icons.edit_rounded), label: const Text('Editar')),
          if (canDelete) OutlinedButton.icon(onPressed: onDelete, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), icon: const Icon(Icons.delete_outline_rounded), label: const Text('Eliminar')),
        ]);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (compact) ...[info, const SizedBox(height: 16), actions] else Row(children: [Expanded(child: info), const SizedBox(width: 12), actions]),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _InfoChip(label: 'Correo', value: user.correo),
            _InfoChip(label: 'Documento', value: '${toDisplayText(user.tipoDocumento)} ${user.numeroDocumento}'),
            _InfoChip(label: 'Contacto', value: user.numeroContacto),
            _InfoChip(label: 'Codigo', value: user.codigoUsuario == 'na' ? 'NA' : user.codigoUsuario),
            _InfoChip(label: 'Contador', value: user.numeroContador == 'na' ? 'NA' : user.numeroContador),
            _InfoChip(label: 'Sector', value: user.sector == 'na' ? 'NA' : toDisplayText(user.sector)),
          ]),
        ]);
      }),
    );
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
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14)),
      child: RichText(
        text: TextSpan(style: Theme.of(context).textTheme.bodyMedium, children: [
          TextSpan(text: '$label: ', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          TextSpan(text: toDisplayText(value)),
        ]),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.width, required this.child});
  final double width;
  final Widget child;
  @override Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(child: Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE0ECE8))), child: const Text('No hay usuarios que coincidan con el filtro actual.')));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No fue posible cargar usuarios.\n$message', textAlign: TextAlign.center)));
  }
}
