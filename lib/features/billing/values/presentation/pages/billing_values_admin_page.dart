import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../users/domain/app_user.dart';
import '../../../periods/data/billing_period_firestore_service.dart';
import '../../../periods/domain/billing_period.dart';
import '../../data/billing_value_config_firestore_service.dart';
import '../../domain/billing_value_config.dart';

part 'billing_values_admin_page_components.dart';
part 'billing_values_admin_page_widgets.dart';

class BillingValuesAdminPage extends StatefulWidget {
  const BillingValuesAdminPage({
    super.key,
    required this.currentUser,
    this.service,
  });

  final AppUser currentUser;
  final BillingValueConfigFirestoreService? service;

  @override
  State<BillingValuesAdminPage> createState() => _BillingValuesAdminPageState();
}

class _BillingValuesAdminPageState extends State<BillingValuesAdminPage> {
  late final BillingValueConfigFirestoreService _service =
      widget.service ?? BillingValueConfigFirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BillingValueConfig>>(
      stream: _service.watchActiveItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('No fue posible cargar los valores de facturación.'),
          );
        }
        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
        }

        final activeItems = snapshot.data ?? const <BillingValueConfig>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              hasActiveConfig: activeItems.isNotEmpty,
              versionLabel: activeItems.isEmpty
                  ? null
                  : '${activeItems.length} vigencia${activeItems.length == 1 ? '' : 's'} activa${activeItems.length == 1 ? '' : 's'}',
              onCreate: () => _openForm(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: activeItems.isEmpty
                  ? const Center(
                      child: Text(
                        'Aún no hay una configuración activa de valores.',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final item in activeItems) ...[
                          _BillingValueCard(
                            item: item,
                            onEdit: () => _openForm(item: item),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openForm({BillingValueConfig? item}) async {
    final result = await showDialog<BillingValueConfig>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _BillingValueDialog(item: item, currentUser: widget.currentUser),
    );

    if (result == null) {
      return;
    }

    try {
      await _service.saveNewVersion(item: result, previousActive: item);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración de valores actualizada correctamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No fue posible guardar: $error')));
    }
  }
}
