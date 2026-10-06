import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';

enum _PickSource { camera, gallery, pdf }

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;
  String? _uploadingType;

  List<_DocumentInfo> _getDocuments() {
    final livreur = context.read<AuthProvider>().livreur;
    final vehiculeLabel = livreur?.vehiculeDocType == 'carte_grise'
        ? 'Carte grise'
        : livreur?.vehiculeDocType == 'permis_conduire'
            ? 'Permis de conduire'
            : 'Permis ou Carte grise';
    return [
      _DocumentInfo(
        type: 'piece_identite',
        title: 'Pièce d\'identité',
        subtitle: 'CNI, passeport ou carte consulaire',
        icon: Icons.badge_outlined,
        url: livreur?.pieceIdentiteUrl,
        allowPdf: true,
      ),
      _DocumentInfo(
        type: 'vehicule_doc',
        title: vehiculeLabel,
        subtitle: 'Permis de conduire OU carte grise du véhicule',
        icon: Icons.drive_eta_outlined,
        url: livreur?.vehiculeDocUrl,
        requiresSubtype: true,
        allowPdf: true,
      ),
      _DocumentInfo(
        type: 'photo_profil',
        title: 'Photo de profil',
        subtitle: 'Photo claire de votre visage (pas de PDF)',
        icon: Icons.camera_alt_outlined,
        url: livreur?.photoProfilUrl,
        allowPdf: false,
      ),
    ];
  }

  Future<void> _pickAndUpload(String documentType, {bool requiresSubtype = false, bool allowPdf = false}) async {
    String? vehiculeDocType;

    if (requiresSubtype) {
      vehiculeDocType = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AppSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSheetHeader(
                icon: Icons.drive_eta_outlined,
                title: 'Quel document véhicule ?',
                message: 'Un seul des deux suffit.',
              ),
              const SizedBox(height: 16),
              _sheetTile(ctx, icon: Icons.drive_eta_outlined, title: 'Carte grise', subtitle: 'Carte grise du véhicule', value: 'carte_grise'),
              _sheetTile(ctx, icon: Icons.badge_outlined, title: 'Permis de conduire', subtitle: 'Votre permis de conduire', value: 'permis_conduire'),
            ],
          ),
        ),
      );
      if (vehiculeDocType == null) return;
    }

    final source = await showModalBottomSheet<_PickSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetHeader(
              icon: Icons.upload_file_rounded,
              title: 'Envoyer le document',
              message: 'Une photo nette, bien éclairée, où tout le texte est lisible.',
            ),
            const SizedBox(height: 16),
            _sheetTile(ctx, icon: Icons.camera_alt_rounded, title: 'Prendre une photo', subtitle: 'Avec l\'appareil photo', value: _PickSource.camera),
            _sheetTile(ctx, icon: Icons.photo_library_rounded, title: 'Choisir dans la galerie', subtitle: 'Une photo déjà prise', value: _PickSource.gallery),
            if (allowPdf)
              _sheetTile(ctx, icon: Icons.picture_as_pdf_rounded, title: 'Fichier PDF', subtitle: 'Un document scanné', value: _PickSource.pdf),
          ],
        ),
      ),
    );

    if (source == null) return;

    String? filePath;

    if (source == _PickSource.pdf) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      filePath = result?.files.single.path;
    } else {
      final imageSource = source == _PickSource.camera ? ImageSource.camera : ImageSource.gallery;
      final image = await _picker.pickImage(
        source: imageSource,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      filePath = image?.path;
    }

    if (filePath == null) return;

    setState(() {
      _isUploading = true;
      _uploadingType = documentType;
    });

    try {
      await _apiService.uploadDocument(documentType, filePath, vehiculeDocType: vehiculeDocType);
      if (mounted) await context.read<AuthProvider>().refreshProfile();
      if (mounted) UIUtils.showSuccess(context, 'Document envoyé');
    } catch (e) {
      if (mounted) UIUtils.showError(context, 'L\'envoi a échoué. Vérifiez votre connexion puis réessayez.');
    } finally {
      if (mounted) setState(() { _isUploading = false; _uploadingType = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    final documents = _getDocuments();
    final uploadedCount = documents.where((d) => d.url != null).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mes documents'),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.shadowMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uploadedCount == 3 ? 'Dossier complet' : '$uploadedCount sur 3 documents envoyés',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    uploadedCount == 3
                        ? 'Notre équipe vérifie vos documents, vous serez prévenu dès la validation.'
                        : 'Envoyez les 3 documents pour que votre compte soit vérifié.',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: uploadedCount / 3,
                      backgroundColor: AppTheme.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(uploadedCount == 3 ? AppTheme.success : AppTheme.accent),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Documents requis', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            const Text('Appuyez sur un document pour l\'envoyer ou le remplacer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ...documents.map((doc) => _buildDocumentCard(doc)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(_DocumentInfo doc) {
    final isUploaded = doc.url != null;
    final isCurrentlyUploading = _isUploading && _uploadingType == doc.type;
    final isPdf = doc.url?.toLowerCase().endsWith('.pdf') == true;
    final fullImageUrl = (!isPdf && doc.url != null) ? doc.url : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
        onTap: _isUploading ? null : () => _pickAndUpload(doc.type, requiresSubtype: doc.requiresSubtype, allowPdf: doc.allowPdf),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: isUploaded ? AppTheme.success : AppTheme.divider, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: isUploaded ? AppTheme.successLight : AppTheme.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  image: fullImageUrl != null
                      ? DecorationImage(image: NetworkImage(fullImageUrl), fit: BoxFit.cover, onError: (_, __) {})
                      : null,
                ),
                child: (fullImageUrl == null)
                    ? Icon(
                        isPdf ? Icons.picture_as_pdf_rounded : doc.icon,
                        size: 24,
                        color: isPdf ? AppTheme.error : (isUploaded ? AppTheme.successDark : AppTheme.textSecondary),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(doc.subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Text(
                      isUploaded ? (isPdf ? 'PDF envoyé' : 'Envoyé') : 'À envoyer',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isUploaded ? AppTheme.successDark : AppTheme.accentDark),
                    ),
                  ],
                ),
              ),
              if (isCurrentlyUploading)
                const BrandDotsPulse(color: AppTheme.accent)
              else
                Icon(
                  isUploaded ? Icons.refresh_rounded : Icons.upload_rounded,
                  color: isUploaded ? AppTheme.textSecondary : AppTheme.accentDark,
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _sheetTile<T>(BuildContext ctx, {required IconData icon, required String title, required String subtitle, required T value}) {
    return ListTile(
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: AppTheme.accentLight, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
        child: Icon(icon, color: AppTheme.accentDark),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
      onTap: () => Navigator.pop(ctx, value),
    );
  }
}

class _DocumentInfo {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? url;
  final bool requiresSubtype;
  final bool allowPdf;

  _DocumentInfo({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.url,
    this.requiresSubtype = false,
    this.allowPdf = false,
  });
}
