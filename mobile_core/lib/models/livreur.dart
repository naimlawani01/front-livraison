class Livreur {
  final String id;
  final String userId;
  final String nomComplet;
  final String? typeVehicule;
  final String? plaqueImmatriculation;
  final String? marqueModele;
  final String? photoProfilUrl;
  final String? pieceIdentiteUrl;
  final String? vehiculeDocUrl;    // permis de conduire OU carte grise
  final String? vehiculeDocType;   // "permis_conduire" | "carte_grise"
  final bool isDisponible;
  final bool isEnCourse;
  final bool isVerified;
  final double noteMoyenne;
  final int nombreCoursesCompletees;
  final int nombreEvaluations;
  final double totalGains;
  final double soldeDisponible;

  Livreur({
    required this.id,
    required this.userId,
    required this.nomComplet,
    this.typeVehicule,
    this.plaqueImmatriculation,
    this.marqueModele,
    this.photoProfilUrl,
    this.pieceIdentiteUrl,
    this.vehiculeDocUrl,
    this.vehiculeDocType,
    required this.isDisponible,
    required this.isEnCourse,
    required this.isVerified,
    required this.noteMoyenne,
    required this.nombreCoursesCompletees,
    required this.nombreEvaluations,
    required this.totalGains,
    this.soldeDisponible = 0.0,
  });

  factory Livreur.fromJson(Map<String, dynamic> json) {
    return Livreur(
      id: json['id'],
      userId: json['user_id'],
      nomComplet: json['nom_complet'],
      typeVehicule: json['type_vehicule'],
      plaqueImmatriculation: json['plaque_immatriculation'],
      marqueModele: json['marque_modele'],
      photoProfilUrl: json['photo_profil_url'],
      pieceIdentiteUrl: json['piece_identite_url'],
      vehiculeDocUrl: json['vehicule_doc_url'],
      vehiculeDocType: json['vehicule_doc_type'],
      isDisponible: json['is_disponible'] ?? false,
      isEnCourse: json['is_en_course'] ?? false,
      isVerified: json['is_verified'] ?? false,
      noteMoyenne: json['note_moyenne']?.toDouble() ?? 0.0,
      nombreCoursesCompletees: json['nombre_courses_completees'] ?? 0,
      nombreEvaluations: json['nombre_evaluations'] ?? 0,
      totalGains: json['total_gains']?.toDouble() ?? 0.0,
      soldeDisponible: json['solde_disponible']?.toDouble() ?? 0.0,
    );
  }
}
