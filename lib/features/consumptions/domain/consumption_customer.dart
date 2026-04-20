class ConsumptionCustomer {
  const ConsumptionCustomer({
    required this.codigoUsuario,
    required this.codigoContador,
    required this.nombreUsuario,
  });

  final String codigoUsuario;
  final String codigoContador;
  final String nombreUsuario;

  String get searchText =>
      '$codigoUsuario $codigoContador $nombreUsuario'.toLowerCase();

  Map<String, dynamic> toMap() {
    return {
      'codigoUsuario': codigoUsuario,
      'codigoContador': codigoContador,
      'nombreUsuario': nombreUsuario,
    };
  }

  factory ConsumptionCustomer.fromMap(Map<String, dynamic> data) {
    return ConsumptionCustomer(
      codigoUsuario: data['codigoUsuario'] as String? ?? '',
      codigoContador: data['codigoContador'] as String? ?? '',
      nombreUsuario: data['nombreUsuario'] as String? ?? '',
    );
  }
}
