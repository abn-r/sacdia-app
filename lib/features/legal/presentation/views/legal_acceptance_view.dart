import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/in_app_browser.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_legal_consent.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
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

    final status = statusAsync.value;
    if (status != null && !status.requiresAcceptance) _selfHeal();

    final c = context.sac;
    final padding = Responsive.formPadding(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: padding,
              // Align (not Center): the scroll view gives unbounded height, and
              // the min height must reach IntrinsicHeight so the Spacers pin the
              // actions to the bottom.
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.maxFormWidth,
                    minHeight: (constraints.maxHeight - padding.vertical)
                        .clamp(0, double.infinity),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),
                        const _Header(),
                        const SizedBox(height: 32),
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
                        const Spacer(),
                        const SizedBox(height: 24),
                        if (status != null)
                          _AcceptButton(
                            isSubmitting: isSubmitting,
                            canAccept: _isChecked(status) &&
                                status.requiresAcceptance &&
                                !isSubmitting,
                            onAccept: () => ref
                                .read(legalAcceptanceNotifierProvider.notifier)
                                .accept(status),
                          ),
                        const SizedBox(height: 4),
                        SacButton.ghost(
                          text: acting
                              ? 'family.banner.back'.tr()
                              : 'legal_gate.sign_out'.tr(),
                          textColor: c.textSecondary,
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

    return [
      if (terms != null || privacy != null) ...[
        const _SectionLabel(),
        _DocumentGroup(
          children: [
            if (terms != null)
              _DocumentRow(
                icon: HugeIcons.strokeRoundedFile02,
                title: 'legal_gate.document_terms'.tr(),
                onRead: () => _openDocument(terms.url),
              ),
            if (privacy != null)
              _DocumentRow(
                icon: HugeIcons.strokeRoundedSecurityCheck,
                title: 'legal_gate.document_privacy'.tr(),
                onRead: () => _openDocument(privacy.url),
              ),
          ],
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
    ];
  }

  List<Widget> _buildError(BuildContext context) {
    return [
      _ErrorCard(message: 'legal_gate.load_error'.tr()),
      const SizedBox(height: 16),
      SacButton.outline(
        text: 'legal_gate.retry'.tr(),
        borderRadius: AppTheme.radiusFull,
        onPressed: () => ref.invalidate(myLegalStatusProvider),
      ),
    ];
  }
}

/// Tinte suave y color de texto del acento, legibles en ambos temas.
///
/// En oscuro, `SacAccent.surface` sigue siendo un tono claro y `dark` pierde
/// contraste sobre negro, así que se derivan del color del acento.
({Color tint, Color text}) _accentTones(BuildContext context) {
  final accent = SacAccent.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return (
    tint: isDark ? accent.color.withValues(alpha: 0.16) : accent.surface,
    text: isDark ? accent.color : accent.dark,
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _accentTones(context).tint,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          alignment: Alignment.center,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedSquareLock02,
            size: 28,
            color: SacAccent.of(context).color,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'legal_gate.title'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'legal_gate.body'.tr(),
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: context.sac.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        'legal_gate.documents_label'.tr().toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.88,
              color: context.sac.textTertiary,
            ),
      ),
    );
  }
}

/// Lista agrupada: una tarjeta con divisores insetados entre filas.
class _DocumentGroup extends StatelessWidget {
  final List<Widget> children;

  const _DocumentGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Padding(
          padding: const EdgeInsets.only(left: _DocumentRow.textInset),
          child: Divider(height: 1, thickness: 1, color: context.sac.ink150),
        ));
      }
      rows.add(children[i]);
    }
    return SacCard(
      padding: EdgeInsets.zero,
      child: Column(children: rows),
    );
  }
}

/// Fila de documento: toda la fila abre el documento.
class _DocumentRow extends StatelessWidget {
  final HugeIconData icon;
  final String title;
  final VoidCallback onRead;

  /// Sangría del texto (padding + icono + separación); alinea los divisores.
  static const double textInset = 14 + 36 + 12;

  const _DocumentRow({
    required this.icon,
    required this.title,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tones = _accentTones(context);
    final readLabel = 'legal_gate.read_document'.tr();

    return SacPressable(
      onTap: onRead,
      semanticLabel: '$readLabel: $title',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tones.tint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: icon,
                  size: 18,
                  color: SacAccent.of(context).color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    title,
                    style: textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      readLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tones.text,
                      ),
                    ),
                    const SizedBox(width: 3),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowUpRight01,
                      size: 14,
                      color: tones.text,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CTA principal: anclado abajo, en la zona del pulgar.
class _AcceptButton extends StatelessWidget {
  final bool isSubmitting;
  final bool canAccept;
  final VoidCallback onAccept;

  const _AcceptButton({
    required this.isSubmitting,
    required this.canAccept,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return SacButton(
      text: 'legal_gate.accept_button'.tr(),
      variant: SacButtonVariant.primary,
      size: SacButtonSize.large,
      fullWidth: true,
      borderRadius: AppTheme.radiusFull,
      isLoading: isSubmitting,
      isEnabled: canAccept,
      onPressed: canAccept ? onAccept : null,
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
              style: const TextStyle(
                  color: AppColors.errorDark, fontSize: SacFontSize.titleSmall),
            ),
          ),
        ],
      ),
    );
  }
}
