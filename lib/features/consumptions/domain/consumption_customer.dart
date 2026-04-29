class ConsumptionCustomer {
  const ConsumptionCustomer({
    required this.codigoUsuario,
    required this.codigoContador,
    required this.nombreUsuario,
    required this.sector,
  });

  final String codigoUsuario;
  final String codigoContador;
  final String nombreUsuario;
  final String sector;

  String get searchText =>
      '$codigoUsuario $codigoContador $nombreUsuario $sector'.toLowerCase();

  Map<String, dynamic> toMap() {
    return {
      'codigoUsuario': codigoUsuario,
      'codigoContador': codigoContador,
      'nombreUsuario': nombreUsuario,
      'sector': sector,
    };
  }

  factory ConsumptionCustomer.fromMap(Map<String, dynamic> data) {
    return ConsumptionCustomer(
      codigoUsuario: data['codigoUsuario'] as String? ?? '',
      codigoContador: data['codigoContador'] as String? ?? '',
      nombreUsuario: data['nombreUsuario'] as String? ?? '',
      sector: data['sector'] as String? ?? '',
    );
  }
}
