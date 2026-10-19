import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/in_app_browser.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_legal_consent.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/auth/presentation/providers/acting_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/entities/legal_status.dart';
import '../providers/legal_providers.dart';

/// Gate bloqueante de aceptación legal.
///
/// Aparece cuando `/auth/me` dice que el usuario no aceptó la versión vigente
/// de los Términos y/o el Aviso de Privacidad. El router lo mantiene como único
/// destino posible mientras `legalAcceptancePending` sea true; las únicas
/// salidas son aceptar o cerrar sesión. Mientras la tutora actúa por un menor,
/// "cerrar sesión" sería cerrar la sesión de ELLA: en su lugar se ofrece
/// volver a su perfil.
class LegalAcceptanceView extends ConsumerStatefulWidget {
  /// Inyectable para pruebas. Por defecto abre el navegador integrado.
  final OpenLegalDocument onOpenDocument;

  const LegalAcceptanceView({
    super.key,
    this.onOpenDocument = openInAppDocument,
  });

  @override
  ConsumerState<LegalAcceptanceView> createState() =>
      _LegalAcceptanceViewState();
}

class _LegalAcceptanceViewState extends ConsumerState<LegalAcceptanceView> {
  /// Versiones (terms|privacy) con las que el usuario marcó la casilla. Si el
  /// backend las cambia, la casilla deja de valer y hay que marcarla de nuevo.
  String? _checkedVersions;
  bool _selfHealScheduled = false;

  static String _versionsKey(LegalStatus status) =>
      '${status.versionOf(LegalDocumentTypes.terms)}|'
      '${status.versionOf(LegalDocumentTypes.privacy)}';

  bool _isChecked(LegalStatus status) =>
      _checkedVersions != null && _checkedVersions == _versionsKey(status);

  Future<void> _openDocument(String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var opened = false;
    try {
      opened = await widget.onOpenDocument(Uri.parse(url));
    } catch (_) {
      opened = false;
    }
    if (opened || messenger == null || !mounted) return;
    SacSnackBar.showMessenger(
      messenger,
      'auth.legal.open_failed'.tr(),
      isError: true,
    );
  }

  /// Aceptado desde otro dispositivo: el backend ya no exige nada, así que se
  /// limpia el gate local y el router nos saca de aquí.
  void _selfHeal() {
    if (_selfHealScheduled) return;
    _selfHealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(authNotifierProvider.notifier).markLegalAccepted();
    });
  }

  Future<void> _signOut() async {
    await ref.read(authNotifierProvider.notifier).signOut();
  }

  /// Mientras se actúa por un menor: sale del modo "actuar por" (S4).
  Future<void> _backToOwnProfile() async {
    await ref.read(authNotifierProvider.notifier).switchProfile(null);
  }

  String _errorText(Object error) {
    if (error is String && error.startsWith('legal_gate.')) return error.tr();
    return legalAcceptErrorKey.tr();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(myLegalStatusProvider);
    final acceptState = ref.watch(legalAcceptanceNotifierProvider);
    final isSubmitting = acceptState.isLoading;
    final acting = ref.watch(actingDependentProvider) != null;

    final status = statusAsync.valueOrNull;
    if (status != null && !status.requiresAcceptance) _selfHeal();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.sac.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: Responsive.formPadding(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: Responsive.maxFormWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedSquareLock02,
                        size: 40,
                        color: AppColors.loginBrandBlueDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'legal_gate.title'.tr(),
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'legal_gate.body'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.sac.textSecondary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (status != null)
                      ..._buildLoaded(
                          context, status, isSubmitting, acceptState)
                    else if (statusAsync.hasError)
                      ..._buildError(context)
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: SacLoading()),
                      ),
                    const SizedBox(height: 8),
                    SacButton.ghost(
                      text: acting
                          ? 'family.banner.back'.tr()
                          : 'legal_gate.sign_out'.tr(),
                      textColor: AppColors.loginBrandBlueDark,
                      isEnabled: !isSubmitting,
                      onPressed: acting ? _backToOwnProfile : _signOut,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLoaded(
    BuildContext context,
    LegalStatus status,
    bool isSubmitting,
    AsyncValue<void> acceptState,
  ) {
    final terms = status.documentOf(LegalDocumentTypes.terms);
    final privacy = status.documentOf(LegalDocumentTypes.privacy);
    final termsUrl = terms?.url ?? AppConstants.termsUrl;
    final privacyUrl = privacy?.url ?? AppConstants.privacyPolicyUrl;
    final checked = _isChecked(status);
    final canAccept = checked && status.requiresAcceptance && !isSubmitting;

    return [
      if (terms != null)
        _DocumentRow(
          title: 'legal_gate.document_terms'.tr(),
          version: terms.version,
          onRead: () => _openDocument(terms.url),
        ),
      if (privacy != null) ...[
        const SizedBox(height: 12),
        _DocumentRow(
          title: 'legal_gate.document_privacy'.tr(),
          version: privacy.version,
          onRead: () => _openDocument(privacy.url),
        ),
      ],
      const SizedBox(height: 20),
      SacLegalConsentCheckbox(
        value: checked,
        enabled: !isSubmitting,
        termsUrl: termsUrl,
        privacyUrl: privacyUrl,
        onOpenDocument: widget.onOpenDocument,
        onChanged: (value) => setState(
          () => _checkedVersions = value ? _versionsKey(status) : null,
        ),
      ),
      if (acceptState.hasError) ...[
        const SizedBox(height: 12),
        _ErrorCard(message: _errorText(acceptState.error!)),
      ],
      const SizedBox(height: 16),
      SacButton(
        text: 'legal_gate.accept_button'.tr(),
        variant: SacButtonVariant.primary,
        size: SacButtonSize.large,
        fullWidth: true,
        backgroundColor: AppColors.loginBrandBlue,
        borderRadius: AppTheme.radiusFull,
        isLoading: isSubmitting,
        isEnabled: canAccept,
        onPressed: canAccept
            ? () => ref
                .read(legalAcceptanceNotifierProvider.notifier)
                .accept(status)
            : null,
      ),
    ];
  }

  List<Widget> _buildError(BuildContext context) {
    return [
      _ErrorCard(message: 'legal_gate.load_error'.tr()),
      const SizedBox(height: 16),
      SacButton.outline(
        text: 'legal_gate.retry'.tr(),
        borderColor: AppColors.loginBrandBlue,
        textColor: AppColors.loginBrandBlueDark,
        borderRadius: AppTheme.radiusFull,
        onPressed: () => ref.invalidate(myLegalStatusProvider),
      ),
    ];
  }
}

class _DocumentRow extends StatelessWidget {
  final String title;
  final String version;
  final VoidCallback onRead;

  const _DocumentRow({
    required this.title,
    required this.version,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    return SacCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedFile01,
            size: 24,
            color: AppColors.loginBrandBlueDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'legal_gate.version_label'
                      .tr(namedArgs: {'version': version}),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.sac.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                SacButton.ghost(
                  text: 'legal_gate.read_document'.tr(),
                  textColor: AppColors.loginBrandBlueDark,
                  onPressed: onRead,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return SacCard(
      backgroundColor: AppColors.errorLight,
      borderColor: AppColors.error.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 20,
            color: AppColors.errorDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.errorDark, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
