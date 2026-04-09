import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/domain/usecases/enroll_previous_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/widgets/enroll_previous_class_skeleton.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/ecclesiastical_year_model.dart';

/// Sheet modal para inscribir al usuario en una clase que completó antes de
/// unirse a la aplicación.
///
/// Flujo:
/// 1. Carga el catálogo completo de clases (todas las categorías: Aventureros,
///    Conquistadores, Guías Mayores) sin filtrar por tipo de club activo.
/// 2. Carga el año eclesiástico actual para asociar la inscripción.
/// 3. El usuario selecciona una clase y confirma.
/// 4. Se invoca [EnrollPreviousClass]; al éxito se invalida [userClassesProvider]
///    y se cierra el sheet.
class EnrollPreviousClassSheet extends ConsumerStatefulWidget {
  const EnrollPreviousClassSheet({super.key});

  @override
  ConsumerState<EnrollPreviousClassSheet> createState() =>
      _EnrollPreviousClassSheetState();
}

class _EnrollPreviousClassSheetState
    extends ConsumerState<EnrollPreviousClassSheet> {
  ProgressiveClass? _selectedClass;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.value;
    final c = context.sac;

    // Si el usuario no está autenticado, mostrar mensaje informativo.
    if (user == null) {
      return _buildNoClubMessage(context, c);
    }

    // Carga TODAS las clases del catálogo sin filtrar por tipo de club,
    // ya que el usuario puede haber completado clases de cualquier categoría.
    final classesAsync = ref.watch(allClassesProvider);
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);

    // Show the shimmer skeleton while either provider is still loading.
    // Both load in parallel and the skeleton covers the entire content area
    // below the header, so there is no half-loaded intermediate state.
    final isLoading = classesAsync.isLoading || yearAsync.isLoading;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, c),
            const SizedBox(height: 20),
            if (isLoading)
              const EnrollPreviousClassSkeleton()
            else ...[
              _buildYearInfo(context, c, yearAsync),
              const SizedBox(height: 16),
              _buildClassList(context, c, classesAsync, yearAsync),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SacColors c) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.school,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inscribir clase anterior',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              Text(
                'Seleccioná una clase que ya completaste',
                style: TextStyle(
                  fontSize: 13,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedCancel01,
            size: 22,
            color: c.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildYearInfo(
    BuildContext context,
    SacColors c,
    AsyncValue<EcclesiasticalYearModel?> yearAsync,
  ) {
    return yearAsync.when(
      // Unreachable: loading state is handled at the build level via
      // EnrollPreviousClassSkeleton before _buildYearInfo is ever called.
      loading: () => const SizedBox.shrink(),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 16, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No se pudo determinar el año eclesiástico actual',
                style: TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
      data: (year) {
        if (year == null) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.warning.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No se pudo determinar el año eclesiástico actual',
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }

        final startYear = year.startDate.year;
        final endYear = year.endDate.year;
        final yearLabel = startYear == endYear
            ? '$startYear'
            : '$startYear–$endYear';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.secondary.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.secondary.withAlpha(60)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 15, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'Año eclesiástico: ',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              Text(
                yearLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassList(
    BuildContext context,
    SacColors c,
    AsyncValue<List<ProgressiveClass>> classesAsync,
    AsyncValue<EcclesiasticalYearModel?> yearAsync,
  ) {
    return classesAsync.when(
      // Unreachable: loading state is handled at the build level via
      // EnrollPreviousClassSkeleton before _buildClassList is ever called.
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Error al cargar clases',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              error.toString().replaceFirst('Exception: ', ''),
              style: TextStyle(fontSize: 13, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SacButton.outline(
              text: 'Reintentar',
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: () => ref.invalidate(allClassesProvider),
            ),
          ],
        ),
      ),
      data: (classes) {
        if (classes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No hay clases disponibles en el catálogo',
                style: TextStyle(fontSize: 14, color: c.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final year = yearAsync.valueOrNull;
        final canSubmit =
            _selectedClass != null && year != null && year.ecclesiasticalYearId > 0 && !_isSubmitting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccioná una clase',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: ListView.separated(
                // shrinkWrap removed: ConstrainedBox(maxHeight) provides a
                // bounded height constraint — ListView can scroll normally.
                itemCount: classes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final cls = classes[index];
                  final isSelected = _selectedClass?.id == cls.id;
                  final classColor = AppColors.classColor(cls.name);
                  final logoAsset = AppColors.classLogoAsset(cls.name);

                  return InkWell(
                    onTap: _isSubmitting
                        ? null
                        : () => setState(() => _selectedClass = cls),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withAlpha(18)
                            : c.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : c.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? AppColors.primary
                                : c.textTertiary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          // Class logo
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: classColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: cls.imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: cls.imageUrl!,
                                      memCacheWidth: 108,  // 36 * 3 (max device pixel ratio)
                                      memCacheHeight: 108, // 36 * 3
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          logoAsset != null
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.all(5),
                                                  child: Image.asset(
                                                    logoAsset,
                                                    fit: BoxFit.contain,
                                                  ),
                                                )
                                              : Center(
                                                  child: HugeIcon(
                                                    icon: HugeIcons
                                                        .strokeRoundedSchool,
                                                    color: classColor,
                                                    size: 18,
                                                  ),
                                                ),
                                    ),
                                  )
                                : logoAsset != null
                                    ? Padding(
                                        padding: const EdgeInsets.all(5),
                                        child: Image.asset(
                                          logoAsset,
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : Center(
                                        child: HugeIcon(
                                          icon:
                                              HugeIcons.strokeRoundedSchool,
                                          color: classColor,
                                          size: 18,
                                        ),
                                      ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cls.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? AppColors.primary
                                    : c.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _submitError!,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SacButton.primary(
              text: 'Inscribirse',
              icon: HugeIcons.strokeRoundedSchool,
              isLoading: _isSubmitting,
              isEnabled: canSubmit,
              onPressed: canSubmit
                  ? () => _submit(context, year)
                  : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoClubMessage(BuildContext context, SacColors c) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedSchool,
              size: 48,
              color: c.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Debés iniciar sesión para inscribir una clase anterior',
              style: TextStyle(
                fontSize: 15,
                color: c.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.outline(
              text: 'Cerrar',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(
      BuildContext context, EcclesiasticalYearModel year) async {
    if (_selectedClass == null) return;

    final userId = ref.read(authNotifierProvider).value?.id;
    if (userId == null) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final useCase = ref.read(enrollPreviousClassUseCaseProvider);
    final result = await useCase(
      EnrollPreviousClassParams(
        userId: userId,
        classId: _selectedClass!.id,
        ecclesiasticalYearId: year.ecclesiasticalYearId,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        final is409 = failure.code == 409 ||
            failure.message.toLowerCase().contains('conflict') ||
            failure.message.toLowerCase().contains('ya est');

        setState(() {
          _isSubmitting = false;
          _submitError = is409
              ? 'Ya estás inscrito en esta clase'
              : failure.message;
        });
      },
      (_) {
        ref.invalidate(userClassesProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inscripción en "${_selectedClass!.name}" registrada exitosamente',
            ),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}
