import 'package:equatable/equatable.dart';

enum SupervisionFolderQueueFilter {
  needsReview('needs_review'),
  evaluated('evaluated'),
  all('all');

  const SupervisionFolderQueueFilter(this.apiValue);

  final String apiValue;
}

enum SupervisionFolderStatus {
  open,
  submitted,
  underEvaluation,
  evaluated,
  closed,
  unknown;

  static SupervisionFolderStatus parse(Object? value) {
    switch (value?.toString().toLowerCase()) {
      case 'open':
        return SupervisionFolderStatus.open;
      case 'submitted':
        return SupervisionFolderStatus.submitted;
      case 'under_evaluation':
        return SupervisionFolderStatus.underEvaluation;
      case 'evaluated':
        return SupervisionFolderStatus.evaluated;
      case 'closed':
        return SupervisionFolderStatus.closed;
      default:
        return SupervisionFolderStatus.unknown;
    }
  }
}

enum SupervisionSectionStatus {
  pending,
  submitted,
  preapprovedLf,
  validated,
  rejected,
  unknown;

  static SupervisionSectionStatus parse(Object? value) {
    switch (value?.toString().toUpperCase()) {
      case 'PENDING':
        return SupervisionSectionStatus.pending;
      case 'SUBMITTED':
        return SupervisionSectionStatus.submitted;
      case 'PREAPPROVED_LF':
        return SupervisionSectionStatus.preapprovedLf;
      case 'VALIDATED':
        return SupervisionSectionStatus.validated;
      case 'REJECTED':
        return SupervisionSectionStatus.rejected;
      default:
        return SupervisionSectionStatus.unknown;
    }
  }
}

class SupervisionFolderQueueItem extends Equatable {
  final String id;
  final String displayName;
  final String clubName;
  final String sectionName;
  final String clubTypeName;
  final String localFieldName;
  final String unionName;
  final String templateName;
  final String yearLabel;
  final SupervisionFolderStatus folderStatus;
  final int totalSections;
  final int submittedSections;
  final int preapprovedSections;
  final int validatedSections;
  final int rejectedSections;
  final List<String> pendingSectionNames;
  final DateTime? latestSubmittedAt;
  final DateTime? createdAt;

  const SupervisionFolderQueueItem({
    required this.id,
    this.displayName = '',
    this.clubName = '',
    this.sectionName = '',
    this.clubTypeName = '',
    this.localFieldName = '',
    this.unionName = '',
    this.templateName = '',
    this.yearLabel = '',
    this.folderStatus = SupervisionFolderStatus.unknown,
    this.totalSections = 0,
    this.submittedSections = 0,
    this.preapprovedSections = 0,
    this.validatedSections = 0,
    this.rejectedSections = 0,
    this.pendingSectionNames = const [],
    this.latestSubmittedAt,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        displayName,
        clubName,
        sectionName,
        clubTypeName,
        localFieldName,
        unionName,
        templateName,
        yearLabel,
        folderStatus,
        totalSections,
        submittedSections,
        preapprovedSections,
        validatedSections,
        rejectedSections,
        pendingSectionNames,
        latestSubmittedAt,
        createdAt,
      ];
}

class SupervisionFolderQueuePage extends Equatable {
  final List<SupervisionFolderQueueItem> items;
  final int total;
  final int page;
  final int limit;

  const SupervisionFolderQueuePage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  @override
  List<Object?> get props => [items, total, page, limit];
}

class SupervisionFolderEvidence extends Equatable {
  final String id;
  final String fileUrl;
  final String fileName;
  final String? notes;
  final String? reviewerNote;
  final String? reviewerNotedByName;
  final DateTime? reviewerNotedAt;
  final String? uploadedByName;
  final DateTime? createdAt;

  const SupervisionFolderEvidence({
    required this.id,
    this.fileUrl = '',
    this.fileName = '',
    this.notes,
    this.reviewerNote,
    this.reviewerNotedByName,
    this.reviewerNotedAt,
    this.uploadedByName,
    this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        fileUrl,
        fileName,
        notes,
        reviewerNote,
        reviewerNotedByName,
        reviewerNotedAt,
        uploadedByName,
        createdAt,
      ];
}

class SupervisionFolderSection extends Equatable {
  /// The `section_id` used in URLs.
  final String id;
  final String name;
  final String? description;
  final int order;
  final bool isRequired;
  final int maxPoints;
  final int? minimumPoints;
  final SupervisionSectionStatus status;
  final int? earnedPoints;
  final String? evaluationNotes;
  final String? lfApproverName;
  final DateTime? lfApprovedAt;
  final String? unionApproverName;
  final DateTime? unionApprovedAt;
  final String? unionDecision;
  final DateTime? submittedAt;
  final List<SupervisionFolderEvidence> evidences;

  const SupervisionFolderSection({
    required this.id,
    this.name = '',
    this.description,
    this.order = 0,
    this.isRequired = false,
    this.maxPoints = 0,
    this.minimumPoints,
    this.status = SupervisionSectionStatus.pending,
    this.earnedPoints,
    this.evaluationNotes,
    this.lfApproverName,
    this.lfApprovedAt,
    this.unionApproverName,
    this.unionApprovedAt,
    this.unionDecision,
    this.submittedAt,
    this.evidences = const [],
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        order,
        isRequired,
        maxPoints,
        minimumPoints,
        status,
        earnedPoints,
        evaluationNotes,
        lfApproverName,
        lfApprovedAt,
        unionApproverName,
        unionApprovedAt,
        unionDecision,
        submittedAt,
        evidences,
      ];
}

class SupervisionFolderDetail extends Equatable {
  final String id;
  final SupervisionFolderStatus status;
  final String clubName;
  final String sectionName;
  final String clubTypeName;
  final String localFieldName;
  final String unionName;
  final String templateName;
  final String yearLabel;
  final int totalEarnedPoints;
  final int totalMaxPoints;
  final double progressPercentage;
  final bool requiresUnionConfirmation;
  final DateTime? submittedAt;
  final DateTime? closedAt;
  final DateTime? evaluatedAt;
  final List<SupervisionFolderSection> sections;

  const SupervisionFolderDetail({
    required this.id,
    this.status = SupervisionFolderStatus.unknown,
    this.clubName = '',
    this.sectionName = '',
    this.clubTypeName = '',
    this.localFieldName = '',
    this.unionName = '',
    this.templateName = '',
    this.yearLabel = '',
    this.totalEarnedPoints = 0,
    this.totalMaxPoints = 0,
    this.progressPercentage = 0,
    this.requiresUnionConfirmation = false,
    this.submittedAt,
    this.closedAt,
    this.evaluatedAt,
    this.sections = const [],
  });

  @override
  List<Object?> get props => [
        id,
        status,
        clubName,
        sectionName,
        clubTypeName,
        localFieldName,
        unionName,
        templateName,
        yearLabel,
        totalEarnedPoints,
        totalMaxPoints,
        progressPercentage,
        requiresUnionConfirmation,
        submittedAt,
        closedAt,
        evaluatedAt,
        sections,
      ];
}
