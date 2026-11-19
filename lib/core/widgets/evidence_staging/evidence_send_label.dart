import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../animations/motion_tokens.dart';
import '../../animations/sac_rolling_number.dart';

/// Label of the footer "Send N files" button.
///
/// Going between two non-zero counts only the number rolls; going to or from
/// zero the whole label cross-fades. The three translations
/// (`btn_send_none`, `btn_send_one`, `btn_send_many`) are kept as they are:
/// the number is found in the translated text, so any language works. When
/// it cannot be found the label simply swaps.
class EvidenceSendLabel extends StatelessWidget {
  const EvidenceSendLabel({super.key, required this.fileCount});

  final int fileCount;

  static const _marker = '\u0001';

  ({String prefix, String suffix})? _split() {
    final String text;
    final String number;
    if (fileCount == 1) {
      text = tr('core.evidence_staging.btn_send_one');
      number = '1';
    } else {
      text = tr(
        'core.evidence_staging.btn_send_many',
        namedArgs: {'count': _marker},
      );
      number = _marker;
    }
    final at = text.indexOf(number);
    if (at < 0) return null;
    return (
      prefix: text.substring(0, at),
      suffix: text.substring(at + number.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    final Widget face;
    if (fileCount <= 0) {
      face = Text(
        tr('core.evidence_staging.btn_send_none'),
        key: const ValueKey('send-label-none'),
      );
    } else {
      final parts = _split();
      face = parts == null
          ? Text(
              fileCount == 1
                  ? tr('core.evidence_staging.btn_send_one')
                  : tr(
                      'core.evidence_staging.btn_send_many',
                      namedArgs: {'count': '$fileCount'},
                    ),
              key: ValueKey('send-label-static-$fileCount'),
            )
          : SacRollingNumber(
              key: const ValueKey('send-label-count'),
              value: fileCount,
              prefix: parts.prefix,
              suffix: parts.suffix,
            );
    }
    return AnimatedSwitcher(
      duration: reduce ? SacMotion.reducedFade : SacMotion.switcher,
      switchInCurve: SacMotion.easeOut,
      switchOutCurve: SacMotion.easeOut,
      child: face,
    );
  }
}
