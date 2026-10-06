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
        backgroundColor: AppTheme.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 20),
                Text('Type de document véhicule', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Choisissez le document que vous souhaitez envoyer',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                _sheetTile(ctx, icon: Icons.drive_eta_outlined, color: AppTheme.accent, bgColor: AppTheme.accentLight,
                    title: 'Carte grise', subtitle: 'Carte grise du véhicule', value: 'carte_grise'),
                _sheetTile(ctx, icon: Icons.badge_outlined, color: AppTheme.info, bgColor: AppTheme.infoLight,
                    title: 'Permis de conduire', subtitle: 'Votre permis de conduire', value: 'permis_conduire'),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
      if (vehiculeDocType == null) return;
    }

    final source = await showModalBottomSheet<_PickSource>(
      context: context,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHandle(),
              const SizedBox(height: 20),
              Text('Choisir une source', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              _sheetTile(ctx, icon: Icons.camera_alt_rounded, color: AppTheme.accent, bgColor: AppTheme.accentLight,
                  title: 'Appareil photo', subtitle: 'Prendre une photo', value: _PickSource.camera),
              _sheetTile(ctx, icon: Icons.photo_library_rounded, color: AppTheme.info, bgColor: AppTheme.infoLight,
                  title: 'Galerie', subtitle: 'Choisir une image existante', value: _PickSource.gallery),
              if (allowPdf)
                _sheetTile(ctx, icon: Icons.picture_as_pdf_rounded, color: const Color(0xFFE53935), bgColor: const Color(0xFFFFEBEE),
                    title: 'Document PDF', subtitle: 'Importer un fichier PDF', value: _PickSource.pdf),
              const SizedBox(height: 8),
            ],
          ),
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
      if (mounted) UIUtils.showSuccess(context, 'Document uploadé avec succès');
    } catch (e) {
      if (mounted) UIUtils.showError(context, 'Erreur : ${e.toString()}');
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
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Mes documents'),
        backgroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.darkGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: const Icon(Icons.folder_outlined, color: AppTheme.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Vos documents', style: TextStyle(color: AppTheme.white, fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('Images ou PDF acceptés', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: uploadedCount / 3,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$uploadedCount / 3 documents envoyés', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Documents requis', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Appuyez sur un document pour l\'envoyer', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
      child: GestureDetector(
        onTap: isCurrentlyUploading ? null : () => _pickAndUpload(doc.type, requiresSubtype: doc.requiresSubtype, allowPdf: doc.allowPdf),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUploaded ? AppTheme.successLight : AppTheme.background,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: isUploaded ? AppTheme.success.withOpacity(0.3) : AppTheme.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: isUploaded ? AppTheme.success.withOpacity(0.1) : AppTheme.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: isUploaded ? AppTheme.success.withOpacity(0.2) : AppTheme.divider),
                  image: fullImageUrl != null
                      ? DecorationImage(image: NetworkImage(fullImageUrl), fit: BoxFit.cover, onError: (_, __) {})
                      : null,
                ),
                child: (fullImageUrl == null)
                    ? Icon(
                        isPdf ? Icons.picture_as_pdf_rounded : doc.icon,
                        size: 24,
                        color: isPdf ? const Color(0xFFE53935) : (isUploaded ? AppTheme.success : AppTheme.textTertiary),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(doc.subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isUploaded ? AppTheme.success.withOpacity(0.12) : AppTheme.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isUploaded ? Icons.check_circle_rounded : Icons.upload_rounded, size: 12, color: isUploaded ? AppTheme.success : AppTheme.accent),
                          const SizedBox(width: 4),
                          Text(
                            isUploaded ? (isPdf ? 'PDF envoyé ✓' : 'Envoyé ✓') : 'À envoyer',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isUploaded ? AppTheme.success : AppTheme.accent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrentlyUploading)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent)))
              else
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isUploaded ? AppTheme.success.withOpacity(0.1) : AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    isUploaded ? Icons.refresh_rounded : (doc.allowPdf ? Icons.upload_file_rounded : Icons.add_a_photo_outlined),
                    size: 18,
                    color: isUploaded ? AppTheme.success : AppTheme.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetHandle() => Container(
    width: 40, height: 4,
    decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
  );

  Widget _sheetTile<T>(BuildContext ctx, {required IconData icon, required Color color, required Color bgColor, required String title, required String subtitle, required T value}) {
    return ListTile(
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
