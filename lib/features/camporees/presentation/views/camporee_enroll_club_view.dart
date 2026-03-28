import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../providers/camporees_providers.dart';

/// Vista para inscribir un club en un camporee.
class CamporeeEnrollClubView extends ConsumerStatefulWidget {
  final int camporeeId;
  final String? camporeeName;

  const CamporeeEnrollClubView({
    super.key,
    required this.camporeeId,
    this.camporeeName,
  });

  @override
  ConsumerState<CamporeeEnrollClubView> createState() =>
      _CamporeeEnrollClubViewState();
}

class _CamporeeEnrollClubViewState
    extends ConsumerState<CamporeeEnrollClubView> {
  final _formKey = GlobalKey<FormState>();
  final _sectionIdCtrl = TextEditingController();

  @override
  void dispose() {
    _sectionIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enrollState =
        ref.watch(enrollClubNotifierProvider(widget.camporeeId));
    final enrolledAsync =
        ref.watch(camporeeEnrolledClubsProvider(widget.camporeeId));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Inscripción de clubes',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: c.text,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Form de inscripción ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedBuilding01,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Inscribir club',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Error
                  if (enrollState.errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedAlert02,
                            color: AppColors.error,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              enrollState.errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    'ID de sección del club *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _sectionIdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'ID de la sección (ej. 42)',
                      hintStyle:
                          TextStyle(fontSize: 13, color: c.textTertiary),
                      prefixIcon: HugeIcon(
                        icon: HugeIcons.strokeRoundedBuilding01,
                        color: c.textTertiary,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: c.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.error),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresá el ID de sección';
                      }
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Ingresá un ID válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  SacButton.primary(
                    text: 'Inscribir club',
                    icon: HugeIcons.strokeRoundedBuilding01,
                    isLoading: enrollState.isLoading,
                    onPressed: enrollState.isLoading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Lista de clubes inscriptos ───────────────────────────────
          Text(
            'Clubes inscriptos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 12),

          enrolledAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                e.toString().replaceFirst('Exception: ', ''),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            data: (clubs) {
              if (clubs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedBuilding01,
                          color: c.textTertiary,
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No hay clubes inscriptos aún',
                          style: TextStyle(
                            fontSize: 14,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: clubs
                    .map((club) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedBuilding01,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        club.clubName ?? 'Club desconocido',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: c.text,
                                        ),
                                      ),
                                      if (club.sectionName != null)
                                        Text(
                                          club.sectionName!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: c.textSecondary,
                                          ),
                                        )
                                      else
                                        Text(
                                          'Sección #${club.clubSectionId}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: c.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Inscripto',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.secondaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    ref
        .read(enrollClubNotifierProvider(widget.camporeeId).notifier)
        .reset();

    final sectionId = int.parse(_sectionIdCtrl.text.trim());
    final success = await ref
        .read(enrollClubNotifierProvider(widget.camporeeId).notifier)
        .enroll(clubSectionId: sectionId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Club inscripto exitosamente'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      _sectionIdCtrl.clear();
    }
  }
}
