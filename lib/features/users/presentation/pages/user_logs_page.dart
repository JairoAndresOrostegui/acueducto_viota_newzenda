import 'package:flutter/material.dart';
import '../../../../core/presentation/text_formatters.dart';
import '../../../../theme/app_colors.dart';
import '../../data/user_audit_log_service.dart';
import '../../domain/user_audit_log.dart';

class UserLogsPage extends StatefulWidget {
  const UserLogsPage({super.key, required this.service});
  final UserAuditLogService service;
  @override State<UserLogsPage> createState() => _UserLogsPageState();
}

class _UserLogsPageState extends State<UserLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Logs de usuarios', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text('Consulta auditoría de ediciones y eliminaciones. La búsqueda usa la primera palabra escrita y devuelve hasta 50 registros.', style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 16),
      TextField(controller: _searchController, onChanged: (value) => setState(() => _query = value), decoration: const InputDecoration(labelText: 'Buscar por palabra', prefixIcon: Icon(Icons.search_rounded))),
      const SizedBox(height: 16),
      Expanded(
        child: StreamBuilder<List<UserAuditLog>>(
          stream: widget.service.watchLogs(query: _query),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('No fue posible cargar los logs.\n${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final logs = snapshot.data!;
            if (logs.isEmpty) return const Center(child: Text('No hay logs para los criterios actuales.'));
            return ListView.separated(
              itemCount: logs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final log = logs[index];
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE0ECE8))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${toDisplayText(log.accion)} · ${toDisplayUserName(log.usuarioObjetivoNombre)}', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text('Responsable: ${toDisplayUserName(log.actorNombre)} · ${_formatDate(log.fecha)}', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    if (log.anterior != null) _LogBlock(title: 'Anterior', data: log.anterior!),
                    if (log.nuevo != null) ...[const SizedBox(height: 10), _LogBlock(title: 'Nuevo', data: log.nuevo!)],
                  ]),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  String _formatDate(DateTime value) => '${value.year}-${_two(value.month)}-${_two(value.day)} ${_two(value.hour)}:${_two(value.minute)}';
  String _two(int n) => n.toString().padLeft(2, '0');
}

class _LogBlock extends StatelessWidget {
  const _LogBlock({required this.title, required this.data});
  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((entry) => entry.value != null && entry.key != 'uid').toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${toDisplayText(entry.key)}: ${toDisplayText('${entry.value}')}'),
          ),
      ]),
    );
  }
}
