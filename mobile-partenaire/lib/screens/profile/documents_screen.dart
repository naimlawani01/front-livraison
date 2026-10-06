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

  Future<void> _pickAndUpload(String documentType, {bool allowPdf = false, bool imageOnly = false}) async {
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
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text('Choisir une source', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppTheme.accentLight, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.accent),
                ),
                title: const Text('Appareil photo', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Prendre une photo', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                onTap: () => Navigator.pop(ctx, _PickSource.camera),
              ),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppTheme.infoLight, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.info),
                ),
                title: const Text('Galerie', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Choisir une photo existante', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                onTap: () => Navigator.pop(ctx, _PickSource.gallery),
              ),
              if (allowPdf && !imageOnly)
                ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE53935)),
                  ),
                  title: const Text('Document PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Importer un fichier PDF', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  onTap: () => Navigator.pop(ctx, _PickSource.pdf),
                ),
              const SizedBox(height: 8),
            ],
          ),
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

    setState(() { _isUploading = true; _uploadingType = documentType; });

    try {
      await _apiService.uploadDevanture(filePath, documentType: documentType);
      if (mounted) await context.read<AuthProvider>().loadExpediteur();
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
    final expediteur = context.read<AuthProvider>().expediteur;

    final devantureDone = expediteur?.devanture_url != null;
    final rccmDone = expediteur?.rccm_url != null;
    final uploadedCount = (devantureDone ? 1 : 0) + (rccmDone ? 1 : 0);

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Documents'),
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
                      value: uploadedCount / 2,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$uploadedCount / 2 documents envoyés',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Documents requis', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Appuyez sur un document pour l\'envoyer', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),

            _buildDocCard(
              documentType: 'devanture',
              title: 'Photo de devanture',
              subtitle: 'Photo claire de l\'entrée de votre commerce (image uniquement)',
              icon: Icons.storefront_outlined,
              url: expediteur?.devanture_url,
              allowPdf: false,
            ),
            _buildDocCard(
              documentType: 'rccm',
              title: 'RCCM',
              subtitle: 'Registre du Commerce — pour les entités formelles (optionnel)',
              icon: Icons.article_outlined,
              url: expediteur?.rccm_url,
              allowPdf: true,
              optional: true,
            ),

            const SizedBox(height: 40),
          ],
        ),
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
    bool optional = false,
  }) {
    final isUploaded = url != null;
    final isPdf = url?.toLowerCase().endsWith('.pdf') == true;
    final imageUrl = (isUploaded && !isPdf) ? url : null;
    final isCurrentlyUploading = _isUploading && _uploadingType == documentType;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: isCurrentlyUploading ? null : () => _pickAndUpload(documentType, allowPdf: allowPdf),
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
                  image: imageUrl != null
                      ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover, onError: (_, __) {})
                      : null,
                ),
                child: imageUrl == null
                    ? Icon(
                        isPdf ? Icons.picture_as_pdf_rounded : icon,
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
                    Row(
                      children: [
                        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        if (optional) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.divider)),
                            child: const Text('optionnel', style: TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                          Icon(isUploaded ? Icons.check_circle_rounded : Icons.upload_rounded,
                              size: 12, color: isUploaded ? AppTheme.success : AppTheme.accent),
                          const SizedBox(width: 4),
                          Text(
                            isUploaded ? (isPdf ? 'PDF envoyé ✓' : 'Envoyé ✓') : 'À envoyer',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: isUploaded ? AppTheme.success : AppTheme.accent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrentlyUploading)
                const SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent)))
              else
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isUploaded ? AppTheme.success.withOpacity(0.1) : AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    isUploaded ? Icons.refresh_rounded : (allowPdf ? Icons.upload_file_rounded : Icons.add_a_photo_outlined),
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
}
