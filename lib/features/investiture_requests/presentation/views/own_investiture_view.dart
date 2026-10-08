import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

/// Pantalla provisional: la ruta ya existe (Task 5) y la vista real llega en
/// una task posterior del plan de la app de investidura por autorización.
class OwnInvestitureView extends StatelessWidget {
  const OwnInvestitureView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: tr('investiture_requests.own.title'),
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: SafeArea(
          top: false,
          child: SacEmptyState(title: tr('investiture_requests.placeholder')),
        ),
      ),
    );
  }
}
