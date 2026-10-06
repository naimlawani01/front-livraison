class User {
  final String id;
  final String phone;
  final String role;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phone: json['phone'],
      role: json['role'],
      isActive: json['is_active'],
      isVerified: json['is_verified'],
      createdAt: DateTime.parse(json['created_at']),
      lastLogin: json['last_login'] != null 
          ? DateTime.parse(json['last_login']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'role': role,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }
}

class Expediteur {
  final String id;
  final String userId;
  /// Valeurs API : restaurant, pharmacie, supermarche, b2b, autre
  final String? typeExpediteur;
  final String nom;
  final String? description;
  final String adresse;
  final double latitude;
  final double longitude;
  final String? email;
  final String? telephoneSecondaire;
  final bool isOpen;
  final bool isVerified;
  final double noteMoyenne;
  final int nombreEvaluations;
  final String? devanture_url;
  final String? rccm_url;

  Expediteur({
    required this.id,
    required this.userId,
    this.typeExpediteur,
    required this.nom,
    this.description,
    required this.adresse,
    required this.latitude,
    required this.longitude,
    this.email,
    this.telephoneSecondaire,
    required this.isOpen,
    required this.isVerified,
    required this.noteMoyenne,
    required this.nombreEvaluations,
    this.devanture_url,
    this.rccm_url,
  });

  factory Expediteur.fromJson(Map<String, dynamic> json) {
    return Expediteur(
      id: json['id'],
      userId: json['user_id'],
      typeExpediteur: json['type_expediteur'],
      nom: json['nom'],
      description: json['description'],
      adresse: json['adresse'],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      email: json['email'],
      telephoneSecondaire: json['telephone_secondaire'],
      isOpen: json['is_open'],
      isVerified: json['is_verified'],
      noteMoyenne: json['note_moyenne'].toDouble(),
      nombreEvaluations: json['nombre_evaluations'],
      devanture_url: json['devanture_url'],
      rccm_url: json['rccm_url'],
    );
  }
}
