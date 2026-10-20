import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/invoice.dart';

class PaymentPreview {
  const PaymentPreview({
    required this.token,
    required this.warnings,
    required this.currentPaid,
    required this.nextPaid,
    required this.pending,
    required this.affectedPeriods,
    required this.priorBalance,
    required this.currentStatus,
    required this.settled,
  });

  final String token;
  final List<String> warnings;
  final int currentPaid;
  final int nextPaid;
  final int pending;
  final List<String> affectedPeriods;
  final int priorBalance;
  final String currentStatus;
  final bool settled;

  factory PaymentPreview.fromMap(Map<String, dynamic> data) => PaymentPreview(
    token: data['token'] as String,
    warnings: List<String>.from(data['warnings'] as List),
    currentPaid: (data['currentPaid'] as num).toInt(),
    nextPaid: (data['nextPaid'] as num).toInt(),
    pending: (data['pending'] as num).toInt(),
    affectedPeriods: List<String>.from(data['affectedPeriods'] as List),
    priorBalance: (data['priorBalance'] as num).toInt(),
    currentStatus: data['currentStatus'] as String,
    settled: data['settled'] == true,
  );
}

class BillingAccountFunctionsService {
  BillingAccountFunctionsService({FirebaseFunctions? functions})
    : _functions = functions;

  final FirebaseFunctions? _functions;

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await (_functions ?? FirebaseFunctions.instance)
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(minutes: 3)),
          )
          .call(data);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'No fue posible actualizar la cuenta.');
    }
  }

  Future<PaymentPreview> previewPayment(Map<String, dynamic> request) async {
    return PaymentPreview.fromMap(
      await _call('previewInvoicePayment', request),
    );
  }

  Future<Map<String, dynamic>> applyPayment(Map<String, dynamic> request) {
    return _call('applyInvoicePayment', request);
  }

  Future<bool> saveInvoice(Invoice invoice, {required bool regenerate}) async {
    final data = invoice.toFirestore();
    for (final key in ['fechaGeneracion', 'fechaVencimiento', 'fechaPago']) {
      if (data[key] is Timestamp) {
        data[key] = (data[key] as Timestamp).toDate().toUtc().toIso8601String();
      }
    }
    final result = await _call('saveAccountInvoice', {
      'period': invoice.periodo,
      'meter': invoice.codigoContador,
      'mode': regenerate ? 'regenerate' : 'create',
      'invoice': data,
    });
    return result['skipped'] != true;
  }
}
