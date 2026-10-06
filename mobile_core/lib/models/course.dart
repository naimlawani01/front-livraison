class Course {
  final String id;
  final String numeroCourse;
  final String expediteurId;
  final String? livreurId;
  final String? adresseClient;
  final double? latitudeClient;
  final double? longitudeClient;
  final String contactClientNom;
  final String contactClientTelephone;
  final String? instructionsSpeciales;
  /// Nature / contenu du colis (pour le livreur)
  final String? descriptionColis;
  final double prixPropose;
  final double commissionPlateforme;
  final double montantLivreur;
  final double? distanceKm;
  final int? dureeEstimeeMinutes;
  final String status;
  final int? noteLivreur;
  final String? commentaireLivreur;
  final DateTime createdAt;
  final DateTime? diffuseeAt;
  final DateTime? accepteeAt;
  final DateTime? recupereeAt;
  final DateTime? livreeAt;
  
  // Sécurité
  final bool exigeCodeLivraison;
  final String? codeLivraison;


  // Infos expediteur (retournées pour le livreur)
  final String? expediteurNom;
  final String? expediteurAdresse;
  final double? expediteurLatitude;
  final double? expediteurLongitude;
  final double? distanceLivreurKm;

  // Infos livreur (retournées par le endpoint détail)
  final String? livreurNom;
  final double? livreurNote;
  final String? livreurTelephone;
  final String? livreurVehicule;
  final int? livreurCoursesCompletees;
  final double? livreurLatitude;
  final double? livreurLongitude;

  // Paiement
  final String modePaiement;
  final String paiementConfirme;
  /// Qui règle la course : `expediteur` (remet la part livreur) ou `client`
  /// (paie le prix complet en Mobile Money).
  final String payeur;
  /// Montant réglé par le payeur : prix complet si client, part livreur (88 %)
  /// si expéditeur (sa commission est prise sur son Crédit).
  final double? montantAEncaisser;
  /// Lien de paiement Mobile Money (renvoyé à l'expéditeur quand c'est lui qui
  /// paie ; jamais au livreur).
  final String? geniuspayCheckoutUrl;
  /// Montant payé par le client à rembourser (course payée puis annulée).
  final double? remboursementDu;

  // Localisation client (lien)
  final String? locationToken;
  final DateTime? locationSharedAt;

  // Suivi client
  final String? trackingToken;

  Course({
    required this.id,
    required this.numeroCourse,
    required this.expediteurId,
    this.livreurId,
    this.adresseClient,
    this.latitudeClient,
    this.longitudeClient,
    required this.contactClientNom,
    required this.contactClientTelephone,
    this.instructionsSpeciales,
    this.descriptionColis,
    required this.prixPropose,
    required this.commissionPlateforme,
    required this.montantLivreur,
    this.distanceKm,
    this.dureeEstimeeMinutes,
    required this.status,
    this.noteLivreur,
    this.commentaireLivreur,
    required this.createdAt,
    this.diffuseeAt,
    this.accepteeAt,
    this.recupereeAt,
    this.livreeAt,

    this.expediteurNom,
    this.expediteurAdresse,
    this.expediteurLatitude,
    this.expediteurLongitude,
    this.distanceLivreurKm,
    this.livreurNom,
    this.livreurNote,
    this.livreurTelephone,
    this.livreurVehicule,
    this.livreurCoursesCompletees,
    this.livreurLatitude,
    this.livreurLongitude,
    this.modePaiement = 'CASH',
    this.paiementConfirme = 'non',
    this.payeur = 'expediteur',
    this.montantAEncaisser,
    this.geniuspayCheckoutUrl,
    this.remboursementDu,
    this.locationToken,
    this.locationSharedAt,
    this.trackingToken,
    this.exigeCodeLivraison = false,
    this.codeLivraison,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    // Parse livreur info si retourné (endpoint détail)
    final livreurData = json['livreur'] as Map<String, dynamic>?;

    return Course(
      id: json['id'],
      numeroCourse: json['numero_course'],
      expediteurId: json['expediteur_id'],
      livreurId: json['livreur_id'],
      adresseClient: json['adresse_client'],
      latitudeClient: json['latitude_client']?.toDouble(),
      longitudeClient: json['longitude_client']?.toDouble(),
      contactClientNom: json['contact_client_nom'],
      contactClientTelephone: json['contact_client_telephone'],
      instructionsSpeciales: json['instructions_speciales'],
      descriptionColis: json['description_colis'],
      prixPropose: json['prix_propose'].toDouble(),
      commissionPlateforme: json['commission_plateforme'].toDouble(),
      montantLivreur: json['montant_livreur'].toDouble(),
      distanceKm: json['distance_km']?.toDouble(),
      dureeEstimeeMinutes: json['duree_estimee_minutes'],
      status: json['status'],
      noteLivreur: json['note_livreur'],
      commentaireLivreur: json['commentaire_livreur'],
      createdAt: DateTime.parse(json['created_at']),
      diffuseeAt: json['diffusee_at'] != null 
          ? DateTime.parse(json['diffusee_at']) 
          : null,
      accepteeAt: json['acceptee_at'] != null 
          ? DateTime.parse(json['acceptee_at']) 
          : null,
      recupereeAt: json['recuperee_at'] != null
          ? DateTime.parse(json['recuperee_at'])
          : null,
      livreeAt: json['livree_at'] != null 
          ? DateTime.parse(json['livree_at']) 
          : null,

      expediteurNom: json['expediteur_nom'] ?? (json['expediteur'] != null ? json['expediteur']['nom'] : null),
      expediteurAdresse: json['expediteur_adresse'] ?? (json['expediteur'] != null ? json['expediteur']['adresse'] : null),
      expediteurLatitude: json['expediteur_latitude']?.toDouble() ?? (json['expediteur'] != null ? json['expediteur']['latitude']?.toDouble() : null),
      expediteurLongitude: json['expediteur_longitude']?.toDouble() ?? (json['expediteur'] != null ? json['expediteur']['longitude']?.toDouble() : null),
      distanceLivreurKm: json['distance_livreur_km']?.toDouble(),
      livreurNom: livreurData?['nom_complet'],
      livreurNote: livreurData?['note_moyenne']?.toDouble(),
      livreurTelephone: livreurData?['telephone'],
      livreurVehicule: livreurData?['type_vehicule'],
      livreurCoursesCompletees: livreurData?['nombre_courses_completees'],
      livreurLatitude: livreurData?['latitude']?.toDouble(),
      livreurLongitude: livreurData?['longitude']?.toDouble(),
      modePaiement: json['mode_paiement'] ?? 'CASH',
      paiementConfirme: json['paiement_confirme'] ?? 'non',
      payeur: json['payeur'] ?? 'expediteur',
      montantAEncaisser: (json['montant_a_encaisser'] as num?)?.toDouble(),
      geniuspayCheckoutUrl: json['geniuspay_checkout_url'],
      remboursementDu: (json['remboursement_du'] as num?)?.toDouble(),
      locationToken: json['location_token'],
      locationSharedAt: json['location_shared_at'] != null
          ? DateTime.parse(json['location_shared_at'])
          : null,
      trackingToken: json['tracking_token'],
      exigeCodeLivraison: json['exige_code_livraison'] ?? false,
      codeLivraison: json['code_livraison'],
    );
  }

  bool get hasClientLocation => latitudeClient != null && longitudeClient != null;
  bool get isPayeurClient => payeur == 'client';
  bool get isMobileMoney => modePaiement.toUpperCase() == 'MOBILE_MONEY';
  bool get isPaiementConfirme => paiementConfirme == 'oui';

  /// Montant que le livreur doit encaisser en espèces chez l'expéditeur
  /// (course cash réglée par l'expéditeur) ; 0 sinon (Mobile Money → Gains).
  double get montantCashARecuperer =>
      (!isMobileMoney && !isPayeurClient) ? montantLivreur : 0;

  String get payeurLabel => isPayeurClient ? 'Payée par le client' : 'Payée par l\'expéditeur';
  bool get isLocationShared => locationSharedAt != null;

  String get modePaiementLabel {
    switch (modePaiement.toUpperCase()) {
      case 'MOBILE_MONEY':
        return 'Mobile Money';
      case 'CASH':
      default:
        return 'Cash à la livraison';
    }
  }

  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'CREEE':
        return 'Créée';
      case 'DIFFUSEE':
        return 'En recherche de livreur';
      case 'ACCEPTEE':
        return 'Livreur en route';
      case 'EN_RECUPERATION':
        return 'Le livreur est arrivé';
      case 'EN_LIVRAISON':
        return 'En cours de livraison';
      case 'TERMINEE':
        return 'Livrée';
      case 'ANNULEE':
        return 'Annulée';
      default:
        return status;
    }
  }
}
