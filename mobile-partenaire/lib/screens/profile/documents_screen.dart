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

  Future<void> _pickAndUpload(String documentType, {bool allowPdf = false}) async {
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
              message: 'Une photo nette, bien éclairée, où tout est lisible.',
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
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      filePath = result?.files.single.path;
    } else {
      final imageSource = source == _PickSource.camera ? ImageSource.camera : ImageSource.gallery;
      final image = await _picker.pickImage(source: imageSource, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
      filePath = image?.path;
    }
    if (filePath == null) return;

    setState(() {
      _isUploading = true;
      _uploadingType = documentType;
    });

    try {
      await _apiService.uploadDevanture(filePath, documentType: documentType);
      if (mounted) await context.read<AuthProvider>().loadExpediteur();
      if (mounted) UIUtils.showSuccess(context, 'Document envoyé');
    } catch (e) {
      if (mounted) UIUtils.showError(context, 'L\'envoi a échoué. Vérifiez votre connexion puis réessayez.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingType = null;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final expediteur = context.watch<AuthProvider>().expediteur;
    final devantureDone = expediteur?.devanture_url != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mes documents'),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
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
                  devantureDone ? 'Document obligatoire envoyé' : '1 document à envoyer',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  devantureDone
                      ? 'Notre équipe vérifie votre commerce, vous serez prévenu dès la validation.'
                      : 'La photo de votre devanture permet de vérifier votre commerce.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildDocCard(
            documentType: 'devanture',
            title: 'Photo de devanture',
            subtitle: 'Photo claire de l\'entrée de votre commerce',
            icon: Icons.storefront_outlined,
            url: expediteur?.devanture_url,
            allowPdf: false,
          ),
          _buildDocCard(
            documentType: 'rccm',
            title: 'RCCM (facultatif)',
            subtitle: 'Registre du commerce, si votre entreprise est enregistrée',
            icon: Icons.article_outlined,
            url: expediteur?.rccm_url,
            allowPdf: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard({
    required String documentType,
    required String title,
    required String subtitle,
    required IconData icon,
    required String? url,
    required bool allowPdf,
  }) {
    final isUploaded = url != null;
    final isPdf = url?.toLowerCase().endsWith('.pdf') == true;
    final imageUrl = (isUploaded && !isPdf) ? url : null;
    final isCurrentlyUploading = _isUploading && _uploadingType == documentType;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          onTap: _isUploading ? null : () => _pickAndUpload(documentType, allowPdf: allowPdf),
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isUploaded ? AppTheme.successLight : AppTheme.background,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    image: imageUrl != null
                        ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover, onError: (_, __) {})
                        : null,
                  ),
                  child: imageUrl == null
                      ? Icon(
                          isPdf ? Icons.picture_as_pdf_rounded : icon,
                          color: isPdf ? AppTheme.error : (isUploaded ? AppTheme.successDark : AppTheme.textSecondary),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
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
}
