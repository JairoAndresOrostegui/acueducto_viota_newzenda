import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/consumption_history_entry.dart';
import '../domain/consumption_reading.dart';

class ConsumptionFirestoreService {
  ConsumptionFirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _periods =>
      _db.collection('periodos');

  CollectionReference<Map<String, dynamic>> _periodConsumptions(
    String period,
  ) => _periods.doc(period).collection('consumos');

  CollectionReference<Map<String, dynamic>> _historyCollection(
    String period,
    String meterCode,
  ) => _periodConsumptions(period).doc(meterCode).collection('historial');

  Future<List<ConsumptionReading>> fetchReadingsForPeriod(String period) async {
    final snapshot = await _periodConsumptions(period).get();
    final items = snapshot.docs
        .map((doc) => ConsumptionReading.fromFirestore(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.codigoContador.compareTo(b.codigoContador));
    return items;
  }

  Future<List<ConsumptionReading>> fetchReadingsReport({
    String? period,
    String? customerCode,
    bool onlyIrregular = false,
  }) async {
    if (period != null && period.isNotEmpty) {
      final items = await fetchReadingsForPeriod(period);
      return items.where((item) {
        if (customerCode != null &&
            customerCode.isNotEmpty &&
            item.codigoUsuario != customerCode) {
          return false;
        }
        if (onlyIrregular && !item.hasIrregularity) {
          return false;
        }
        return true;
      }).toList()
        ..sort((a, b) {
          final userCompare = a.nombreUsuario.compareTo(b.nombreUsuario);
          if (userCompare != 0) {
            return userCompare;
          }
          return a.codigoContador.compareTo(b.codigoContador);
        });
    }

    final snapshot = await _db.collectionGroup('consumos').get();
    final items = snapshot.docs
        .map((doc) => ConsumptionReading.fromFirestore(doc.id, doc.data()))
        .where((item) {
          if (customerCode != null &&
              customerCode.isNotEmpty &&
              item.codigoUsuario != customerCode) {
            return false;
          }
          if (onlyIrregular && !item.hasIrregularity) {
            return false;
          }
          return true;
        })
        .toList()
      ..sort((a, b) {
        final periodCompare = b.periodoActual.compareTo(a.periodoActual);
        if (periodCompare != 0) {
          return periodCompare;
        }
        final userCompare = a.nombreUsuario.compareTo(b.nombreUsuario);
        if (userCompare != 0) {
          return userCompare;
        }
        return a.codigoContador.compareTo(b.codigoContador);
      });
    return items;
  }

  Future<ConsumptionReading?> fetchReading({
    required String period,
    required String meterCode,
  }) async {
    final snapshot = await _periodConsumptions(period).doc(meterCode).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return ConsumptionReading.fromFirestore(snapshot.id, snapshot.data()!);
  }

  Future<ConsumptionReading?> fetchReadingById(String readingId) async {
    final parts = readingId.split('|');
    if (parts.length != 2) {
      return null;
    }
    return fetchReading(period: parts.first, meterCode: parts.last);
  }

  Future<ConsumptionReading?> fetchLatestPreviousReading({
    required String meterCode,
    required String currentPeriod,
  }) async {
    final periods = await _fetchPeriodIds();
    periods
      ..removeWhere((period) => period.compareTo(currentPeriod) >= 0)
      ..sort((a, b) => b.compareTo(a));

    for (final period in periods) {
      final reading = await fetchReading(period: period, meterCode: meterCode);
      if (reading != null) {
        return reading;
      }
    }
    return null;
  }

  Future<List<ConsumptionReading>> fetchSubsequentReadings({
    required String meterCode,
    required String fromPeriodExclusive,
  }) async {
    final periods = await _fetchPeriodIds();
    periods
      ..removeWhere((period) => period.compareTo(fromPeriodExclusive) <= 0)
      ..sort();

    final readings = <ConsumptionReading>[];
    for (final period in periods) {
      final reading = await fetchReading(period: period, meterCode: meterCode);
      if (reading != null) {
        readings.add(reading);
      }
    }
    return readings;
  }

  Future<List<String>> _fetchPeriodIds() async {
    final snapshot = await _periods.get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<void> saveReading(
    ConsumptionReading reading, {
    ConsumptionHistoryEntry? historyEntry,
  }) async {
    final docRef = _periodConsumptions(reading.periodoActual)
        .doc(reading.codigoContador);
    await _db.runTransaction((transaction) async {
      transaction.set(docRef, reading.toFirestore(), SetOptions(merge: true));
      if (historyEntry != null) {
        transaction.set(
          _historyCollection(reading.periodoActual, reading.codigoContador)
              .doc(historyEntry.id),
          historyEntry.toFirestore(),
        );
      }
    });
  }

  Future<void> appendHistory(
    ConsumptionReading reading,
    ConsumptionHistoryEntry entry,
  ) {
    return _historyCollection(reading.periodoActual, reading.codigoContador)
        .doc(entry.id)
        .set(entry.toFirestore());
  }

  Future<void> updateReadingWithCascade({
    required ConsumptionReading updatedReading,
    required ConsumptionHistoryEntry updateEntry,
    required String actorUid,
    required String actorName,
    required String actorRole,
  }) async {
    if (updatedReading.facturado || updatedReading.pagado) {
      throw StateError('No se puede modificar un consumo facturado o pagado.');
    }
    final impactedPeriods = <String>[];
    await saveReading(updatedReading, historyEntry: updateEntry);

    var previous = updatedReading;
    final subsequent = await fetchSubsequentReadings(
      meterCode: updatedReading.codigoContador,
      fromPeriodExclusive: updatedReading.periodoActual,
    );

    for (final item in subsequent) {
      if (item.facturado || item.pagado) {
        break;
      }
      final recalculated = item.copyWith(
        lecturaAnterior: previous.lecturaActual,
        consumoCalculado: item.lecturaActual - previous.lecturaActual,
        estado: item.facturado ? 'ajuste_pendiente' : item.estado,
      );
      impactedPeriods.add(item.periodoActual);
      await saveReading(
        recalculated,
        historyEntry: ConsumptionHistoryEntry(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          tipoEvento: 'recalculo_cascada',
          actorUid: actorUid,
          actorNombre: actorName,
          actorRol: actorRole,
          fecha: DateTime.now(),
          estadoAnterior: item.estado,
          estadoNuevo: recalculated.estado,
          valorAnterior: item.consumoCalculado,
          valorNuevo: recalculated.consumoCalculado,
          motivo: item.facturado
              ? 'El período ya estaba facturado y requiere ajuste manual.'
              : 'Recálculo por edición administrativa de un período anterior.',
          periodosImpactados: impactedPeriods,
        ),
      );
      previous = recalculated;
      if (item.facturado) {
        break;
      }
    }
  }
}
