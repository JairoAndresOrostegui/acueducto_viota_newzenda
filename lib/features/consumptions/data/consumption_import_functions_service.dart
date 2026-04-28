import 'package:cloud_functions/cloud_functions.dart';

class ConsumptionImportFunctionsService {
  ConsumptionImportFunctionsService({FirebaseFunctions? functions})
      : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _client => _functions ?? FirebaseFunctions.instance;

  Future<ConsumptionImportSummary> importReadings({
    required String period,
    required List<Map<String, String>> rows,
  }) async {
    final callable = _client.httpsCallable(
      'importConsumptionReadings',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 30)),
    );
    final result = await callable.call({
      'periodo': period,
      'rows': rows,
    });
    return ConsumptionImportSummary.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }
}

class ConsumptionImportSummary {
  const ConsumptionImportSummary({
    required this.imported,
    required this.ignored,
    required this.failed,
    required this.period,
    required this.results,
  });

  final int imported;
  final int ignored;
  final int failed;
  final String period;
  final List<ConsumptionImportRowResult> results;

  List<ConsumptionImportRowResult> get ignoredRows =>
      results.where((item) => item.ignored).toList();

  factory ConsumptionImportSummary.fromMap(Map<String, dynamic> data) {
    final rawResults = data['results'] as List<dynamic>? ?? const [];
    return ConsumptionImportSummary(
      imported: data['imported'] as int? ?? 0,
      ignored: data['ignored'] as int? ?? 0,
      failed: data['failed'] as int? ?? 0,
      period: data['period'] as String? ?? '',
      results: rawResults
          .map(
            (item) => ConsumptionImportRowResult.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class ConsumptionImportRowResult {
  const ConsumptionImportRowResult({
    required this.rowNumber,
    required this.ok,
    required this.ignored,
    this.codigoUsuario,
    this.codigoContador,
    this.message,
  });

  final int rowNumber;
  final bool ok;
  final bool ignored;
  final String? codigoUsuario;
  final String? codigoContador;
  final String? message;

  factory ConsumptionImportRowResult.fromMap(Map<String, dynamic> data) {
    return ConsumptionImportRowResult(
      rowNumber: data['rowNumber'] as int? ?? 0,
      ok: data['ok'] == true,
      ignored: data['ignored'] == true,
      codigoUsuario: data['codigoUsuario'] as String?,
      codigoContador: data['codigoContador'] as String?,
      message: data['message'] as String?,
    );
  }
}
