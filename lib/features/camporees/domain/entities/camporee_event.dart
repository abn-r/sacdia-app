import 'package:equatable/equatable.dart';

/// Persona del roster de un camporí asignable a eventos de agenda.
class CamporeeStaffMember extends Equatable {
  final String? staffMemberId;
  final String? category;
  final String? roleLabel;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? userImageUrl;

  const CamporeeStaffMember({
    this.staffMemberId,
    this.category,
    this.roleLabel,
    this.userId,
    this.userName,
    this.userEmail,
    this.userImageUrl,
  });

  String? get displayName {
    final name = userName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final label = roleLabel?.trim();
    if (label != null && label.isNotEmpty) return label;

    return null;
  }

  @override
  List<Object?> get props => [
        staffMemberId,
        category,
        roleLabel,
        userId,
        userName,
        userEmail,
        userImageUrl,
      ];
}

/// Asignación de personal del roster a un evento de agenda.
class CamporeeEventStaffAssignment extends Equatable {
  final String? assignmentId;
  final String? staffMemberId;
  final String assignmentRole;
  final String? titleOverride;
  final String? notes;
  final int displayOrder;
  final bool active;
  final CamporeeStaffMember? staffMember;

  const CamporeeEventStaffAssignment({
    this.assignmentId,
    this.staffMemberId,
    required this.assignmentRole,
    this.titleOverride,
    this.notes,
    this.displayOrder = 0,
    this.active = true,
    this.staffMember,
  });

  bool get isResponsible => assignmentRole == 'responsible';
  bool get isAssistant => assignmentRole == 'assistant';
  bool get isEvaluator => assignmentRole == 'evaluator';
  bool get isSupport => assignmentRole == 'support';

  String? get compactDisplayName {
    final staffName = staffMember?.displayName?.trim();
    if (staffName != null && staffName.isNotEmpty) return staffName;

    final title = titleOverride?.trim();
    if (title != null && title.isNotEmpty) return title;

    return null;
  }

  @override
  List<Object?> get props => [
        assignmentId,
        staffMemberId,
        assignmentRole,
        titleOverride,
        notes,
        displayOrder,
        active,
        staffMember,
      ];
}

/// Bloque opcional de agenda para segmentar un evento por horario/grupo.
class CamporeeEventScheduleBlock extends Equatable {
  final String? scheduleBlockId;
  final String? title;
  final String? description;
  final int dayNumber;
  final String? startsAt;
  final String? endsAt;
  final String? venueName;
  final int? capacity;
  final String? notes;
  final List<String> assignedSectionNames;

  const CamporeeEventScheduleBlock({
    this.scheduleBlockId,
    this.title,
    this.description,
    required this.dayNumber,
    this.startsAt,
    this.endsAt,
    this.venueName,
    this.capacity,
    this.notes,
    this.assignedSectionNames = const [],
  });

  bool get hasTime => startsAt != null && startsAt!.trim().isNotEmpty;

  @override
  List<Object?> get props => [
        scheduleBlockId,
        title,
        description,
        dayNumber,
        startsAt,
        endsAt,
        venueName,
        capacity,
        notes,
        assignedSectionNames,
      ];
}

/// Especialidad de preparación ligada a un evento de camporí.
class CamporeeEventHonor extends Equatable {
  final int honorId;
  final String name;
  final String? honorImage;
  final String? materialUrl;
  final String? categoryName;
  final int? skillLevel;
  final bool active;

  const CamporeeEventHonor({
    required this.honorId,
    required this.name,
    this.honorImage,
    this.materialUrl,
    this.categoryName,
    this.skillLevel,
    this.active = true,
  });

  bool get hasMaterial {
    final url = materialUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  @override
  List<Object?> get props => [
        honorId,
        name,
        honorImage,
        materialUrl,
        categoryName,
        skillLevel,
        active,
      ];
}

/// Evento/actividad registrada dentro de un camporí.
class CamporeeEvent extends Equatable {
  final int camporeeEventId;
  final String title;
  final String? description;
  final int maxPoints;
  final int minPoints;
  final int dayNumber;
  final String? startsAt;
  final String? endsAt;
  final String displayCategory;
  final String status;
  final List<String> sections;
  final String? venueName;
  final String? leaderName;
  final int? durationSeconds;
  final String participantsMode;
  final int? participantsCount;
  final bool agendaVisible;
  final String? eventTypeCode;
  final String? eventTypeName;
  final List<CamporeeEventScheduleBlock> scheduleBlocks;
  final List<CamporeeEventStaffAssignment> staffAssignments;
  final List<CamporeeEventHonor> honors;

  const CamporeeEvent({
    required this.camporeeEventId,
    required this.title,
    this.description,
    required this.maxPoints,
    required this.minPoints,
    required this.dayNumber,
    this.startsAt,
    this.endsAt,
    required this.displayCategory,
    required this.status,
    this.sections = const [],
    this.venueName,
    this.leaderName,
    this.durationSeconds,
    required this.participantsMode,
    this.participantsCount,
    this.agendaVisible = true,
    this.eventTypeCode,
    this.eventTypeName,
    this.scheduleBlocks = const [],
    this.staffAssignments = const [],
    this.honors = const [],
  });

  bool get hasTime =>
      agendaVisible && startsAt != null && startsAt!.trim().isNotEmpty;

  List<CamporeeEventStaffAssignment> get activeStaffAssignments =>
      staffAssignments.where((assignment) => assignment.active).toList();

  List<CamporeeEventStaffAssignment> get responsibleAssignments =>
      activeStaffAssignments
          .where((assignment) => assignment.isResponsible)
          .toList();

  List<CamporeeEventStaffAssignment> get assistantAssignments =>
      activeStaffAssignments
          .where((assignment) => assignment.isAssistant)
          .toList();

  List<CamporeeEventStaffAssignment> get evaluatorAssignments =>
      activeStaffAssignments
          .where((assignment) => assignment.isEvaluator)
          .toList();

  List<CamporeeEventStaffAssignment> get supportAssignments =>
      activeStaffAssignments
          .where((assignment) => assignment.isSupport)
          .toList();

  List<CamporeeEventStaffAssignment> get supportingAssignments =>
      activeStaffAssignments
          .where(
            (assignment) =>
                assignment.isAssistant ||
                assignment.isEvaluator ||
                assignment.isSupport,
          )
          .toList();

  List<String> get responsibleDisplayNames =>
      _compactDisplayNames(responsibleAssignments);

  List<String> get supportingDisplayNames =>
      _compactDisplayNames(supportingAssignments);

  static List<String> _compactDisplayNames(
    List<CamporeeEventStaffAssignment> assignments,
  ) {
    final seen = <String>{};
    final names = <String>[];

    for (final assignment in assignments) {
      final name = assignment.compactDisplayName?.trim();
      if (name == null || name.isEmpty || seen.contains(name)) continue;
      seen.add(name);
      names.add(name);
    }

    return names;
  }

  @override
  List<Object?> get props => [
        camporeeEventId,
        title,
        description,
        maxPoints,
        minPoints,
        dayNumber,
        startsAt,
        endsAt,
        displayCategory,
        status,
        sections,
        venueName,
        leaderName,
        durationSeconds,
        participantsMode,
        participantsCount,
        agendaVisible,
        eventTypeCode,
        eventTypeName,
        scheduleBlocks,
        staffAssignments,
        honors,
      ];
}
