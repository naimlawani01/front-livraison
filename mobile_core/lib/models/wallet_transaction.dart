class WalletSummary {
  final double soldeDisponible;
  final double totalGains;
  final int nombreCourses;

  WalletSummary({
    required this.soldeDisponible,
    required this.totalGains,
    required this.nombreCourses,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) => WalletSummary(
        soldeDisponible: (json['solde_disponible'] ?? 0).toDouble(),
        totalGains: (json['total_gains'] ?? 0).toDouble(),
        nombreCourses: (json['nombre_courses'] ?? 0) as int,
      );
}

class WalletTransaction {
  final String id;
  final String type;       // credit | retrait | bonus
  final double montant;
  final double soldeAvant;
  final double soldeApres;
  final String? description;
  final String statut;     // complete | en_attente | refuse
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.montant,
    required this.soldeAvant,
    required this.soldeApres,
    this.description,
    required this.statut,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'],
        type: json['type'],
        montant: (json['montant'] ?? 0).toDouble(),
        soldeAvant: (json['solde_avant'] ?? 0).toDouble(),
        soldeApres: (json['solde_apres'] ?? 0).toDouble(),
        description: json['description'],
        statut: json['statut'] ?? 'complete',
        createdAt: DateTime.parse(json['created_at']),
      );
}
