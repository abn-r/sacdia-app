import '../../domain/entities/class_module_detail.dart';
import '../../domain/entities/class_requirement.dart';

/// Group a requirement belongs to on the module screen, in display order.
enum ModuleRequirementGroup { toFix, unsent, sent, validated }

bool _isSentBack(ClassRequirement r) =>
    r.status == RequirementStatus.rechazado ||
    r.status == RequirementStatus.observado;

/// Requirements in curriculum order: `displayOrder` first, then by name.
List<ClassRequirement> sortedRequirements(List<ClassRequirement> requirements) {
  final sorted = List<ClassRequirement>.from(requirements);
  sorted.sort((a, b) {
    final aOrder = a.displayOrder ?? 1 << 20;
    final bOrder = b.displayOrder ?? 1 << 20;
    if (aOrder != bOrder) return aOrder.compareTo(bOrder);
    return a.name.compareTo(b.name);
  });
  return sorted;
}

/// The requirements of a module split in [ModuleRequirementGroup]s, in this
/// order: to fix (rejected and observed), not sent, sent, validated. Empty
/// groups are left out.
List<(ModuleRequirementGroup, List<ClassRequirement>)> groupModuleRequirements(
  List<ClassRequirement> requirements,
) {
  final sorted = sortedRequirements(requirements);
  List<ClassRequirement> where(bool Function(ClassRequirement) test) =>
      sorted.where(test).toList();

  final groups = <ModuleRequirementGroup, List<ClassRequirement>>{
    ModuleRequirementGroup.toFix: where(_isSentBack),
    ModuleRequirementGroup.unsent:
        where((r) => r.status == RequirementStatus.pendiente),
    ModuleRequirementGroup.sent:
        where((r) => r.status == RequirementStatus.enviado),
    ModuleRequirementGroup.validated:
        where((r) => r.status == RequirementStatus.validado),
  };
  return [
    for (final entry in groups.entries)
      if (entry.value.isNotEmpty) (entry.key, entry.value),
  ];
}

/// What "Por atender" lists for the whole class: first what was sent back,
/// then what the member already started but has not sent (not sent yet with
/// files uploaded). Modules keep their order.
///
/// Staged files that were never uploaded live only on the device and are not
/// part of the model; "started" means files already uploaded to the server.
List<ClassRequirement> attentionRequirements(
  List<ClassModuleDetail> modules,
) {
  final all = [
    for (final m in modules) ...sortedRequirements(m.requirements),
  ];
  return [
    ...all.where(_isSentBack),
    ...all.where(
      (r) => r.status == RequirementStatus.pendiente && r.files.isNotEmpty,
    ),
  ];
}
