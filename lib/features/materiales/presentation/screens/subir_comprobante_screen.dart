import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/comprobantes_provider.dart';
import '../providers/orden_detail_provider.dart';
import '../widgets/price_input.dart';

// ── Constantes de validación ──────────────────────────────────────────────────

const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
const List<String> _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

/// Pantalla "Subir comprobante" — el director selecciona un archivo PDF o
/// imagen de su comprobante bancario, rellena el monto, referencia y fecha
/// y envía el formulario.
///
/// Ruta: /home/materiales/orden/:folio/comprobante
class SubirComprobanteScreen extends ConsumerStatefulWidget {
  final String folioOrId;

  const SubirComprobanteScreen({super.key, required this.folioOrId});

  @override
  ConsumerState<SubirComprobanteScreen> createState() =>
      _SubirComprobanteScreenState();
}

class _SubirComprobanteScreenState
    extends ConsumerState<SubirComprobanteScreen> {
  final _formKey = GlobalKey<FormState>();

  File? _selectedFile;
  String? _selectedFileName;
  int? _selectedFileSizeBytes;
  String? _fileError;

  int _montoCentavos = 0;
  final _refController = TextEditingController();
  DateTime? _fechaPago;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  // ── File picker ─────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.first;
    if (pickedFile.path == null) return;

    final file = File(pickedFile.path!);
    final sizeBytes = pickedFile.size;

    // Client-side size validation (mirrors backend REQ-CMP-002)
    if (sizeBytes > _maxFileSizeBytes) {
      setState(() {
        _selectedFile = null;
        _selectedFileName = null;
        _selectedFileSizeBytes = null;
        _fileError = 'El archivo supera el límite de 10 MB.';
      });
      return;
    }

    setState(() {
      _selectedFile = file;
      _selectedFileName = pickedFile.name;
      _selectedFileSizeBytes = sizeBytes;
      _fileError = null;
    });
  }

  // ── Date picker ─────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaPago ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now, // Cannot be a future date (Mexico TZ approximation)
    );
    if (picked != null) {
      setState(() => _fechaPago = picked);
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    // Validate file selection
    if (_selectedFile == null) {
      setState(() => _fileError = 'Seleccioná un archivo para continuar.');
      return;
    }

    // Validate form fields
    if (!_formKey.currentState!.validate()) return;

    if (_fechaPago == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná la fecha de pago.')),
      );
      return;
    }

    await ref.read(uploadComprobanteNotifierProvider.notifier).upload(
          UploadComprobanteArgs(
            folioOrId: widget.folioOrId,
            file: _selectedFile!,
            montoCentavos: _montoCentavos,
            refBancariaDeclarada: _refController.text.trim(),
            fechaPago: _fechaPago!,
          ),
        );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadComprobanteNotifierProvider);

    // React to success
    ref.listen(uploadComprobanteNotifierProvider, (prev, next) {
      if (next.result != null && prev?.result == null) {
        // Invalidate the order detail so it refreshes
        ref.invalidate(ordenDetailProvider(widget.folioOrId));
        if (context.mounted) {
          context.go(RouteNames.materialesOrdenDetail(widget.folioOrId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Comprobante enviado. El campo local lo validará pronto.'),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
      }
      if (next.errorMessage != null && prev?.errorMessage == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Subir comprobante')),
      body: uploadState.isLoading
          ? _UploadProgress(progress: uploadState.progress)
          : _FormBody(
              formKey: _formKey,
              selectedFileName: _selectedFileName,
              selectedFileSizeBytes: _selectedFileSizeBytes,
              fileError: _fileError,
              fechaPago: _fechaPago,
              refController: _refController,
              onPickFile: _pickFile,
              onPickDate: _pickDate,
              onMontoChanged: (c) => _montoCentavos = c,
              onSubmit: _submit,
            ),
    );
  }
}

// ── Upload progress view ─────────────────────────────────────────────────────

class _UploadProgress extends StatelessWidget {
  final double progress;
  const _UploadProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_outlined,
                size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Enviando comprobante…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: AppColors.primarySurface,
              color: AppColors.primary,
            ),
            if (progress > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: AppColors.lightTextSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Form body ────────────────────────────────────────────────────────────────

class _FormBody extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String? selectedFileName;
  final int? selectedFileSizeBytes;
  final String? fileError;
  final DateTime? fechaPago;
  final TextEditingController refController;
  final VoidCallback onPickFile;
  final VoidCallback onPickDate;
  final ValueChanged<int> onMontoChanged;
  final VoidCallback onSubmit;

  const _FormBody({
    required this.formKey,
    required this.selectedFileName,
    required this.selectedFileSizeBytes,
    required this.fileError,
    required this.fechaPago,
    required this.refController,
    required this.onPickFile,
    required this.onPickDate,
    required this.onMontoChanged,
    required this.onSubmit,
  });

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── File picker area ─────────────────────────────────────────────────
          _SectionLabel(label: 'Archivo del comprobante'),
          const SizedBox(height: 8),
          if (selectedFileName == null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color:
                      fileError != null ? AppColors.error : AppColors.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.attach_file),
              label: const Text('Seleccionar archivo (PDF, JPG, PNG)'),
              onPressed: onPickFile,
            )
          else
            _FilePreview(
              fileName: selectedFileName!,
              fileSize: _formatFileSize(selectedFileSizeBytes ?? 0),
              onReplace: onPickFile,
            ),
          if (fileError != null) ...[
            const SizedBox(height: 4),
            Text(
              fileError!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ],

          const SizedBox(height: 20),

          // ── Monto pagado ─────────────────────────────────────────────────────
          _SectionLabel(label: 'Monto pagado'),
          const SizedBox(height: 8),
          PriceInput(
            label: 'Monto pagado',
            hint: '0.00',
            onChanged: onMontoChanged,
          ),

          const SizedBox(height: 20),

          // ── Referencia bancaria ──────────────────────────────────────────────
          _SectionLabel(label: 'Referencia / Concepto que escribiste'),
          const SizedBox(height: 8),
          TextFormField(
            controller: refController,
            decoration: const InputDecoration(
              labelText: 'Concepto de la transferencia',
              hintText: 'Ej: SOL20260001',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresá la referencia que usaste.';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // ── Fecha de pago ─────────────────────────────────────────────────────
          _SectionLabel(label: 'Fecha de pago'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onPickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.lightBorder),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fechaPago != null
                          ? _formatDate(fechaPago!)
                          : 'Seleccionar fecha',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fechaPago != null
                            ? AppColors.lightText
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.lightTextSecondary),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Submit ────────────────────────────────────────────────────────────
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Enviar comprobante'),
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

// ── File preview card ─────────────────────────────────────────────────────────

class _FilePreview extends StatelessWidget {
  final String fileName;
  final String fileSize;
  final VoidCallback onReplace;

  const _FilePreview({
    required this.fileName,
    required this.fileSize,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insert_drive_file_outlined,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  fileSize,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onReplace,
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }
}

// ── Shared label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.lightText,
          ),
    );
  }
}
