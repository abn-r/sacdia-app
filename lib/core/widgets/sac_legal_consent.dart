import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/in_app_browser.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

/// Abre un documento legal. Devuelve false si no se pudo abrir.
typedef OpenLegalDocument = Future<bool> Function(Uri uri);

/// Minimum touch target (dp) for the consent row.
const double _kMinTapTarget = 48;

/// Owns the two link recognizers so both widgets dispose them the same way.
class _LegalLinks {
  _LegalLinks({required this.onTapTerms, required this.onTapPrivacy}) {
    _terms.onTap = onTapTerms;
    _privacy.onTap = onTapPrivacy;
  }

  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;
  final TapGestureRecognizer _terms = TapGestureRecognizer();
  final TapGestureRecognizer _privacy = TapGestureRecognizer();

  static const TextStyle _linkStyle = TextStyle(
    color: AppColors.loginBrandBlueDark,
    fontWeight: FontWeight.w700,
  );

  /// `terms_link` + `and` + `privacy_link`.
  List<InlineSpan> spans() => [
        TextSpan(
          text: 'auth.legal.terms_link'.tr(),
          style: _linkStyle,
          recognizer: _terms,
        ),
        TextSpan(text: 'auth.legal.and'.tr()),
        TextSpan(
          text: 'auth.legal.privacy_link'.tr(),
          style: _linkStyle,
          recognizer: _privacy,
        ),
      ];

  void dispose() {
    _terms.dispose();
    _privacy.dispose();
  }
}

Future<void> _openOrWarn(
  BuildContext context,
  OpenLegalDocument open,
  String url,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await open(Uri.parse(url));
  } catch (_) {
    opened = false;
  }
  if (opened || messenger == null || !context.mounted) return;
  SacSnackBar.showMessenger(
    messenger,
    'auth.legal.open_failed'.tr(),
    isError: true,
  );
}

/// Checkbox "He leído y acepto los Términos y el Aviso de Privacidad" con los
/// dos documentos como enlaces tocables.
///
/// Es la evidencia visible de consentimiento: el estado `value` lo lleva quien
/// la usa (registro, gate de aceptación).
class SacLegalConsentCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String termsUrl;
  final String privacyUrl;
  final bool enabled;

  /// Llave de traducción del texto que precede a los enlaces. Por defecto "He
  /// leído y acepto los "; Mi familia usa la variante "en nombre del menor".
  final String prefixKey;

  /// Inyectable para pruebas. Por defecto abre el navegador integrado.
  final OpenLegalDocument onOpenDocument;

  const SacLegalConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.termsUrl,
    required this.privacyUrl,
    this.enabled = true,
    this.prefixKey = 'auth.legal.consent_prefix',
    this.onOpenDocument = openInAppDocument,
  });

  @override
  State<SacLegalConsentCheckbox> createState() =>
      _SacLegalConsentCheckboxState();
}

class _SacLegalConsentCheckboxState extends State<SacLegalConsentCheckbox> {
  late final _LegalLinks _links = _LegalLinks(
    onTapTerms: () =>
        _openOrWarn(context, widget.onOpenDocument, widget.termsUrl),
    onTapPrivacy: () =>
        _openOrWarn(context, widget.onOpenDocument, widget.privacyUrl),
  );

  @override
  void dispose() {
    _links.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.sac.textSecondary,
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinTapTarget),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            label: 'auth.legal.consent_semantics'.tr(),
            child: Checkbox(
              value: widget.value,
              onChanged: widget.enabled
                  ? (checked) => widget.onChanged(checked ?? false)
                  : null,
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text.rich(
                TextSpan(
                  text: widget.prefixKey.tr(),
                  style: style,
                  children: _links.spans(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso estático "Al continuar, aceptas los Términos y el Aviso de
/// Privacidad" (login). No es evidencia de aceptación.
class SacLegalNoticeText extends StatefulWidget {
  final String termsUrl;
  final String privacyUrl;

  /// Inyectable para pruebas. Por defecto abre el navegador integrado.
  final OpenLegalDocument onOpenDocument;

  const SacLegalNoticeText({
    super.key,
    required this.termsUrl,
    required this.privacyUrl,
    this.onOpenDocument = openInAppDocument,
  });

  @override
  State<SacLegalNoticeText> createState() => _SacLegalNoticeTextState();
}

class _SacLegalNoticeTextState extends State<SacLegalNoticeText> {
  late final _LegalLinks _links = _LegalLinks(
    onTapTerms: () =>
        _openOrWarn(context, widget.onOpenDocument, widget.termsUrl),
    onTapPrivacy: () =>
        _openOrWarn(context, widget.onOpenDocument, widget.privacyUrl),
  );

  @override
  void dispose() {
    _links.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.sac.textSecondary,
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinTapTarget),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text.rich(
            TextSpan(
              text: 'auth.legal.login_notice_prefix'.tr(),
              style: style,
              children: _links.spans(),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
