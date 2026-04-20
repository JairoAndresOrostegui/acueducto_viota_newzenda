import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/consumption_customer.dart';
import '../domain/consumption_reading.dart';

class ConsumptionLocalCacheService {
  static const String _periodKey = 'consumos_periodo_actual';
  static const String _customersKey = 'consumos_clientes_cache';
  static const String _readingsKey = 'consumos_lecturas_locales';

  Future<String?> loadActivePeriod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_periodKey);
  }

  Future<void> saveActivePeriod(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_periodKey, value);
  }

  Future<List<ConsumptionCustomer>> loadCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customersKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ConsumptionCustomer.fromMap)
        .toList();
  }

  Future<void> saveCustomers(List<ConsumptionCustomer> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customersKey,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
  }

  Future<List<ConsumptionReading>> loadReadings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_readingsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ConsumptionReading.fromMap)
        .toList();
  }

  Future<void> saveReadings(List<ConsumptionReading> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _readingsKey,
      jsonEncode(items.map((item) => item.toMap()).toList()),
    );
  }
}
