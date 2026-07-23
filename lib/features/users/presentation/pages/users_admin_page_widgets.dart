part of 'users_admin_page.dart';

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
    required this.canResetAccount,
    required this.onEdit,
    required this.onResetAccount,
    required this.onDelete,
  });

  final AppUser user;
  final bool canDelete;
  final bool canResetAccount;
  final VoidCallback onEdit;
  final VoidCallback onResetAccount;
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
              if (canResetAccount)
                OutlinedButton.icon(
                  onPressed: onResetAccount,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: Colors.orange.shade900,
                  ),
                  icon: const Icon(Icons.cleaning_services_rounded),
                  label: const Text('Limpiar cuenta'),
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
                        ? (user.sector == 'na'
                              ? 'NA'
                              : toDisplayText(user.sector))
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
