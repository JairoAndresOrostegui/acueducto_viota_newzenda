class ConsumptionIrregularity {
  const ConsumptionIrregularity({
    required this.tipo,
    required this.descripcion,
    required this.reportadoPorUid,
    required this.reportadoPorNombre,
    required this.fechaReporte,
    this.lecturaObservada,
    this.requiereRevisionAdmin = true,
  });

  final String tipo;
  final String descripcion;
  final String reportadoPorUid;
  final String reportadoPorNombre;
  final DateTime fechaReporte;
  final int? lecturaObservada;
  final bool requiereRevisionAdmin;

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'descripcion': descripcion,
      'reportadoPorUid': reportadoPorUid,
      'reportadoPorNombre': reportadoPorNombre,
      'fechaReporte': fechaReporte.toIso8601String(),
      'lecturaObservada': lecturaObservada,
      'requiereRevisionAdmin': requiereRevisionAdmin,
    };
  }

  factory ConsumptionIrregularity.fromMap(Map<String, dynamic> data) {
    return ConsumptionIrregularity(
      tipo: data['tipo'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      reportadoPorUid: data['reportadoPorUid'] as String? ?? '',
      reportadoPorNombre: data['reportadoPorNombre'] as String? ?? '',
      fechaReporte:
          DateTime.tryParse(data['fechaReporte'] as String? ?? '') ??
          DateTime.now(),
      lecturaObservada: data['lecturaObservada'] as int?,
      requiereRevisionAdmin:
          data['requiereRevisionAdmin'] as bool? ?? true,
    );
  }
}
