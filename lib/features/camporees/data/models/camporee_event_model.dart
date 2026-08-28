import 'package:equatable/equatable.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/camporee_event.dart';

class CamporeeStaffMemberModel extends Equatable {
  final String? staffMemberId;
  final String? category;
  final String? roleLabel;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? userImageUrl;

  const CamporeeStaffMemberModel({
    this.staffMemberId,
    this.category,
    this.roleLabel,
    this.userId,
    this.userName,
    this.userEmail,
    this.userImageUrl,
  });

  factory CamporeeStaffMemberModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? fallback,
  }) {
    final user = _firstMap(
      json['user'],
      json['users'],
      json['basic_user'],
      fallback?['user'],
      fallback?['users'],
      fallback?['basic_user'],
    );

    return CamporeeStaffMemberModel(
      staffMemberId: _firstString(
        json['camporee_staff_member_id'],
        json['staff_member_id'],
        json['id'],
        fallback?['camporee_staff_member_id'],
        fallback?['staff_member_id'],
      ),
      category: _firstString(
        json['category'],
        json['staff_category'],
        fallback?['category'],
        fallback?['staff_category'],
      ),
      roleLabel: _firstString(
        json['role_label'],
        json['roleLabel'],
        json['staff_role_label'],
        fallback?['role_label'],
        fallback?['roleLabel'],
        fallback?['staff_role_label'],
      ),
      userId: _firstString(
        json['user_id'],
        user?['user_id'],
        user?['id'],
        fallback?['user_id'],
      ),
      userName: _resolveName(json, user, fallback),
      userEmail: _firstString(
        json['user_email'],
        json['email'],
        user?['email'],
        fallback?['user_email'],
        fallback?['email'],
      ),
      userImageUrl: _firstString(
        json['user_image'],
        json['user_image_url'],
        json['image_url'],
        json['avatar_url'],
        user?['user_image'],
        user?['image_url'],
        user?['avatar_url'],
        fallback?['user_image'],
        fallback?['user_image_url'],
        fallback?['image_url'],
        fallback?['avatar_url'],
      ),
    );
  }

  CamporeeStaffMember toEntity() {
    return CamporeeStaffMember(
      staffMemberId: staffMemberId,
      category: category,
      roleLabel: roleLabel,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userImageUrl: userImageUrl,
    );
  }

  static Map<String, dynamic>? _firstMap(dynamic first,
      [dynamic second,
      dynamic third,
      dynamic fourth,
      dynamic fifth,
      dynamic sixth]) {
    for (final value in [first, second, third, fourth, fifth, sixth]) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static String? _firstString(dynamic first,
      [dynamic second,
      dynamic third,
      dynamic fourth,
      dynamic fifth,
      dynamic sixth,
      dynamic seventh,
      dynamic eighth,
      dynamic ninth,
      dynamic tenth,
      dynamic eleventh,
      dynamic twelfth]) {
    for (final value in [
      first,
      second,
      third,
      fourth,
      fifth,
      sixth,
      seventh,
      eighth,
      ninth,
      tenth,
      eleventh,
      twelfth,
    ]) {
      final parsed = safeStringOrNull(value)?.trim();
      if (parsed != null && parsed.isNotEmpty) return parsed;
    }
    return null;
  }

  static String? _resolveName(
    Map<String, dynamic> json,
    Map<String, dynamic>? user,
    Map<String, dynamic>? fallback,
  ) {
    final explicit = _firstString(
      user?['full_name'],
      user?['display_name'],
      user?['user_name'],
      json['full_name'],
      json['display_name'],
      json['user_name'],
      json['staff_member_name'],
      fallback?['full_name'],
      fallback?['display_name'],
      fallback?['user_name'],
      fallback?['staff_member_name'],
    );
    if (explicit != null) return explicit;

    return _composeName(user) ?? _composeName(json) ?? _composeName(fallback);
  }

  static String? _composeName(Map<String, dynamic>? json) {
    if (json == null) return null;
    final parts = [
      safeStringOrNull(json['name']),
      safeStringOrNull(json['paternal_last_name']),
      safeStringOrNull(json['maternal_last_name']),
    ]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return null;
    return parts.join(' ');
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

class CamporeeEventStaffAssignmentModel extends Equatable {
  final String? assignmentId;
  final String? staffMemberId;
  final String assignmentRole;
  final String? titleOverride;
  final String? notes;
  final int displayOrder;
  final bool active;
  final CamporeeStaffMemberModel? staffMember;

  const CamporeeEventStaffAssignmentModel({
    this.assignmentId,
    this.staffMemberId,
    required this.assignmentRole,
    this.titleOverride,
    this.notes,
    this.displayOrder = 0,
    this.active = true,
    this.staffMember,
  });

  factory CamporeeEventStaffAssignmentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final nestedStaffMember = _asMap(
      json['camporee_staff_member'] ?? json['staff_member'],
    );
    final staffMember = nestedStaffMember != null || _hasFlattenedStaff(json)
        ? CamporeeStaffMemberModel.fromJson(
            nestedStaffMember ?? const <String, dynamic>{},
            fallback: json,
          )
        : null;

    return CamporeeEventStaffAssignmentModel(
      assignmentId: safeStringOrNull(
        json['camporee_event_staff_assignment_id'] ?? json['id'],
      ),
      staffMemberId: safeStringOrNull(
        json['camporee_staff_member_id'] ??
            json['staff_member_id'] ??
            staffMember?.staffMemberId,
      ),
      assignmentRole:
          safeString(json['assignment_role'], 'support').trim().toLowerCase(),
      titleOverride: safeStringOrNull(json['title_override']),
      notes: safeStringOrNull(json['notes']),
      displayOrder: safeInt(json['display_order']),
      active: safeBool(json['active'], true),
      staffMember: staffMember,
    );
  }

  CamporeeEventStaffAssignment toEntity() {
    return CamporeeEventStaffAssignment(
      assignmentId: assignmentId,
      staffMemberId: staffMemberId,
      assignmentRole: assignmentRole,
      titleOverride: titleOverride,
      notes: notes,
      displayOrder: displayOrder,
      active: active,
      staffMember: staffMember?.toEntity(),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static bool _hasFlattenedStaff(Map<String, dynamic> json) {
    return json.containsKey('camporee_staff_member_id') ||
        json.containsKey('staff_member_id') ||
        json.containsKey('user_id') ||
        json.containsKey('user_name') ||
        json.containsKey('staff_member_name');
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

class CamporeeEventScheduleBlockModel extends Equatable {
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

  const CamporeeEventScheduleBlockModel({
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

  factory CamporeeEventScheduleBlockModel.fromJson(Map<String, dynamic> json) {
    final venue = json['venue'] is Map<String, dynamic>
        ? json['venue'] as Map<String, dynamic>
        : null;
    final assignments = json['assignments'];

    return CamporeeEventScheduleBlockModel(
      scheduleBlockId:
          safeStringOrNull(json['camporee_event_schedule_block_id']),
      title: safeStringOrNull(json['title']),
      description: safeStringOrNull(json['description']),
      dayNumber: safeInt(json['day_number'], 1),
      startsAt: safeStringOrNull(json['starts_at']),
      endsAt: safeStringOrNull(json['ends_at']),
      venueName: safeStringOrNull(venue?['name']),
      capacity: safeIntOrNull(json['capacity']),
      notes: safeStringOrNull(json['notes']),
      assignedSectionNames: assignments is List
          ? assignments
              .whereType<Map>()
              .map((item) => _assignmentLabel(Map<String, dynamic>.from(item)))
              .whereType<String>()
              .toList()
          : const [],
    );
  }

  static String? _assignmentLabel(Map<String, dynamic> json) {
    final section = json['club_section'] is Map<String, dynamic>
        ? json['club_section'] as Map<String, dynamic>
        : null;
    final nested = section?['club_types'] ?? section?['club_type'];
    final typeName = nested is Map ? safeStringOrNull(nested['name']) : null;
    final sectionName = typeName ?? safeStringOrNull(section?['name']);
    final club = section?['clubs'] is Map<String, dynamic>
        ? section!['clubs'] as Map<String, dynamic>
        : null;
    final clubName = safeStringOrNull(club?['name']);
    if (clubName != null && sectionName != null) {
      return '$clubName · $sectionName';
    }
    return sectionName ?? clubName;
  }

  CamporeeEventScheduleBlock toEntity() {
    return CamporeeEventScheduleBlock(
      scheduleBlockId: scheduleBlockId,
      title: title,
      description: description,
      dayNumber: dayNumber,
      startsAt: startsAt,
      endsAt: endsAt,
      venueName: venueName,
      capacity: capacity,
      notes: notes,
      assignedSectionNames: assignedSectionNames,
    );
  }

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

class CamporeeEventHonorModel extends Equatable {
  final int honorId;
  final String name;
  final String? honorImage;
  final String? materialUrl;
  final String? categoryName;
  final int? skillLevel;
  final bool active;

  const CamporeeEventHonorModel({
    required this.honorId,
    required this.name,
    this.honorImage,
    this.materialUrl,
    this.categoryName,
    this.skillLevel,
    this.active = true,
  });

  factory CamporeeEventHonorModel.fromJson(Map<String, dynamic> json) {
    return CamporeeEventHonorModel(
      honorId: safeInt(json['honor_id'] ?? json['id']),
      name: safeString(json['name']),
      honorImage: safeStringOrNull(json['honor_image'] ?? json['image_url']),
      materialUrl: safeStringOrNull(json['material_url'] ?? json['materialUrl']),
      categoryName: safeStringOrNull(
        json['category_name'] ?? json['honor_category_name'],
      ),
      skillLevel: safeIntOrNull(json['skill_level']),
      active: safeBool(json['active'], true),
    );
  }

  CamporeeEventHonor toEntity() {
    return CamporeeEventHonor(
      honorId: honorId,
      name: name,
      honorImage: honorImage,
      materialUrl: materialUrl,
      categoryName: categoryName,
      skillLevel: skillLevel,
      active: active,
    );
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

/// Modelo de evento de camporí para la capa de datos.
class CamporeeEventModel extends Equatable {
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
  final List<CamporeeEventScheduleBlockModel> scheduleBlocks;
  final List<CamporeeEventStaffAssignmentModel> staffAssignments;
  final List<CamporeeEventHonorModel> honors;

  const CamporeeEventModel({
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
    required this.sections,
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

  factory CamporeeEventModel.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'];
    final venue = json['venue'] is Map<String, dynamic>
        ? json['venue'] as Map<String, dynamic>
        : null;
    final leader = json['leader'] is Map<String, dynamic>
        ? json['leader'] as Map<String, dynamic>
        : null;
    final eventType = json['event_type'] is Map<String, dynamic>
        ? json['event_type'] as Map<String, dynamic>
        : null;
    final rawBlocks = json['schedule_blocks'];
    final staffAssignments = _staffAssignmentsFromJson(json);
    final rawHonors = json['honors'];

    return CamporeeEventModel(
      camporeeEventId: safeInt(json['camporee_event_id'] ?? json['id']),
      title: safeString(json['title']),
      description: safeStringOrNull(json['description']),
      maxPoints: safeInt(json['max_points']),
      minPoints: safeInt(json['min_points']),
      dayNumber: safeInt(json['day_number'], 1),
      startsAt: safeStringOrNull(json['starts_at']),
      endsAt: safeStringOrNull(json['ends_at']),
      displayCategory: safeString(json['display_category'], 'logistico'),
      status: safeString(json['status'], 'programado'),
      sections: rawSections is List
          ? rawSections.map((value) => value.toString()).toList()
          : const [],
      venueName: safeStringOrNull(venue?['name']),
      leaderName: _resolveLeaderName(json, leader),
      durationSeconds: safeIntOrNull(json['duration_seconds']),
      participantsMode: safeString(json['participants_mode'], 'count'),
      participantsCount: safeIntOrNull(json['participants_count']),
      agendaVisible: json['agenda_visible'] != false,
      eventTypeCode: safeStringOrNull(eventType?['code']),
      eventTypeName: safeStringOrNull(eventType?['name']),
      scheduleBlocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map>()
              .map(
                (item) => CamporeeEventScheduleBlockModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
      staffAssignments: staffAssignments,
      honors: rawHonors is List
          ? rawHonors
              .whereType<Map>()
              .map(
                (item) => CamporeeEventHonorModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }

  static String? _resolveLeaderName(
    Map<String, dynamic> json,
    Map<String, dynamic>? leader,
  ) {
    final override = safeStringOrNull(json['leader_name_override']);
    final firstName = safeStringOrNull(leader?['name']);
    if (firstName != null && firstName.trim().isNotEmpty) {
      final paternal = safeStringOrNull(leader?['paternal_last_name']);
      final fullName = '${firstName.trim()} ${paternal ?? ''}'.trim();
      return fullName.isEmpty ? null : fullName;
    }
    return override;
  }

  static List<CamporeeEventStaffAssignmentModel> _staffAssignmentsFromJson(
    Map<String, dynamic> json,
  ) {
    final rawAssignments = json['staff_assignments'] ??
        json['staffAssignments'] ??
        json['event_staff_assignments'] ??
        json['camporee_event_staff_assignments'] ??
        (_looksLikeStaffAssignments(json['assignments'])
            ? json['assignments']
            : null);

    if (rawAssignments is! List) return const [];

    final assignments = rawAssignments
        .whereType<Map>()
        .map(
          (item) => CamporeeEventStaffAssignmentModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList()
      ..sort((a, b) {
        final order = a.displayOrder.compareTo(b.displayOrder);
        if (order != 0) return order;
        return a.assignmentRole.compareTo(b.assignmentRole);
      });

    return assignments;
  }

  static bool _looksLikeStaffAssignments(dynamic value) {
    if (value is! List) return false;
    return value.whereType<Map>().any((item) {
      return item.containsKey('assignment_role') ||
          item.containsKey('camporee_event_staff_assignment_id') ||
          item.containsKey('camporee_staff_member_id') ||
          item.containsKey('camporee_staff_member') ||
          item.containsKey('staff_member');
    });
  }

  CamporeeEvent toEntity() {
    return CamporeeEvent(
      camporeeEventId: camporeeEventId,
      title: title,
      description: description,
      maxPoints: maxPoints,
      minPoints: minPoints,
      dayNumber: dayNumber,
      startsAt: startsAt,
      endsAt: endsAt,
      displayCategory: displayCategory,
      status: status,
      sections: sections,
      venueName: venueName,
      leaderName: leaderName,
      durationSeconds: durationSeconds,
      participantsMode: participantsMode,
      participantsCount: participantsCount,
      agendaVisible: agendaVisible,
      eventTypeCode: eventTypeCode,
      eventTypeName: eventTypeName,
      scheduleBlocks: scheduleBlocks.map((block) => block.toEntity()).toList(),
      staffAssignments:
          staffAssignments.map((assignment) => assignment.toEntity()).toList(),
      honors: honors.map((honor) => honor.toEntity()).toList(),
    );
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
