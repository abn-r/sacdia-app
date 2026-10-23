import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/providers/family_providers.dart';

import '../widgets/delete_account_dependents_dialog.dart';
import 'delete_account_flow.dart';

/// Consulta `deletion-impact` y, si hay menores a cargo, muestra el aviso con
/// la casilla de confirmación.
///
/// - Sin menores, o si la consulta falla / tarda más de [timeout]: devuelve
///   [DependentsAck.none]. Si en realidad hay menores el servidor lo dirá con
///   409 `AUTH_DELETE_DEPENDENTS_ACK_REQUIRED` y [DeleteAccountFlow] reintenta.
/// - [refresh] fuerza una lista nueva (después de un 409).
Future<DependentsAck> confirmDeletionDependents(
  BuildContext context,
  WidgetRef ref, {
  bool refresh = false,
  Duration timeout = const Duration(seconds: 10),
}) async {
  if (refresh) ref.invalidate(deletionImpactProvider);

  List<DeletionImpactEntry> dependents;
  try {
    dependents = await ref.read(deletionImpactProvider.future).timeout(timeout);
  } catch (_) {
    return DependentsAck.none;
  }
  if (dependents.isEmpty) return DependentsAck.none;
  if (!context.mounted) return DependentsAck.cancelled;

  final accepted = await SacDialog.present<bool>(
    context,
    barrierDismissible: false,
    builder: (_) => DeleteAccountDependentsDialog(dependents: dependents),
  );
  return accepted == true
      ? DependentsAck.acknowledged
      : DependentsAck.cancelled;
}
