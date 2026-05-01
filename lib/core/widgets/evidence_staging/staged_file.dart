import 'package:equatable/equatable.dart';

import '../../../features/classes/domain/entities/requirement_evidence.dart'
    as classes;
import '../../../features/evidence_folder/domain/entities/evidence_file.dart'
    as evidence;

/// Status of a file within the staging area.
enum StagedFileStatus {
  /// Already uploaded and confirmed on the server.
  uploaded,

  /// Picked locally, not yet sent.
  local,

  /// Currently being uploaded.
  uploading,

  /// Upload finished successfully.
  completed,

  /// Upload failed.
  error,
}

/// Unified file model for the evidence staging area.
///
/// Both `RequirementEvidence` (classes) and `EvidenceFile` (evidence folders)
/// are mapped to this model before being passed to `EvidenceStagingManager`.
/// Local files (picked but not uploaded) use [status] = [StagedFileStatus.local].
class StagedFile extends Equatable {
  /// UUID for remote files, generated locally (milliseconds timestamp) for new ones.
  final String id;

  /// Display name of the file.
  final String name;

  /// `'image'` or `'pdf'`.
  final String type;

  final StagedFileStatus status;

  /// Local filesystem path — only present for locally staged files.
  final String? localPath;

  /// Remote URL (signed) — only present for already-uploaded files.
  final String? remoteUrl;

  /// MIME type (e.g. `'image/jpeg'`, `'application/pdf'`).
  final String? mimeType;

  /// Upload progress from 0.0 to 1.0.
  final double uploadProgress;

  /// Error message if upload failed.
  final String? errorMessage;

  /// Name of the person who uploaded the file (remote files only).
  final String? uploadedBy;

  /// Timestamp of when the file was uploaded (remote files only).
  final DateTime? uploadedAt;

  /// Reviewer note left by assistant-lf / director-lf via the admin panel.
  ///
  /// Only populated for [EvidenceFile] instances (evidence folder feature).
  /// Always null for [RequirementEvidence] (classes feature).
  /// Read-only — the app never writes this field.
  final String? reviewerNote;

  const StagedFile({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.localPath,
    this.remoteUrl,
    this.mimeType,
    this.uploadProgress = 0.0,
    this.errorMessage,
    this.uploadedBy,
    this.uploadedAt,
    this.reviewerNote,
  });

  // ── Computed helpers ──────────────────────────────────────────────────────

  bool get isImage => type == 'image';
  bool get isPdf => type == 'pdf';
  bool get isLocal => status == StagedFileStatus.local;
  bool get isRemote => status == StagedFileStatus.uploaded;

  // ── copyWith ──────────────────────────────────────────────────────────────

  /// Sentinel object used to distinguish "not provided" from "set to null"
  /// for nullable fields in [copyWith].
  static const _sentinel = Object();

  /// Creates a copy with the given fields replaced.
  ///
  /// Nullable fields ([errorMessage], [localPath], [remoteUrl], [mimeType],
  /// [uploadedBy], [uploadedAt]) use a sentinel pattern so they can be
  /// explicitly cleared by passing `null`:
  /// ```dart
  /// file.copyWith(errorMessage: null) // clears errorMessage
  /// file.copyWith()                   // keeps existing errorMessage
  /// ```
  StagedFile copyWith({
    String? id,
    String? name,
    String? type,
    StagedFileStatus? status,
    Object? localPath = _sentinel,
    Object? remoteUrl = _sentinel,
    Object? mimeType = _sentinel,
    double? uploadProgress,
    Object? errorMessage = _sentinel,
    Object? uploadedBy = _sentinel,
    Object? uploadedAt = _sentinel,
    Object? reviewerNote = _sentinel,
  }) {
    return StagedFile(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      localPath: identical(localPath, _sentinel)
          ? this.localPath
          : localPath as String?,
      remoteUrl: identical(remoteUrl, _sentinel)
          ? this.remoteUrl
          : remoteUrl as String?,
      mimeType: identical(mimeType, _sentinel)
          ? this.mimeType
          : mimeType as String?,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      uploadedBy: identical(uploadedBy, _sentinel)
          ? this.uploadedBy
          : uploadedBy as String?,
      uploadedAt: identical(uploadedAt, _sentinel)
          ? this.uploadedAt
          : uploadedAt as DateTime?,
      reviewerNote: identical(reviewerNote, _sentinel)
          ? this.reviewerNote
          : reviewerNote as String?,
    );
  }

  // ── Factory: from RequirementEvidence (classes feature) ───────────────────

  /// Maps a `RequirementEvidence` to a `StagedFile` with status `uploaded`.
  factory StagedFile.fromRequirementEvidence(classes.RequirementEvidence e) {
    return StagedFile(
      id: e.id,
      name: e.fileName,
      type: e.isImage ? 'image' : 'pdf',
      status: StagedFileStatus.uploaded,
      remoteUrl: e.url,
      mimeType: e.isImage ? 'image/jpeg' : 'application/pdf',
      uploadedBy: e.uploadedByName,
      uploadedAt: e.uploadedAt,
    );
  }

  // ── Factory: from EvidenceFile (evidence folder feature) ──────────────────

  /// Maps an `EvidenceFile` to a `StagedFile` with status `uploaded`.
  factory StagedFile.fromEvidenceFile(evidence.EvidenceFile e) {
    return StagedFile(
      id: e.id,
      name: e.fileName,
      type: e.isImage ? 'image' : 'pdf',
      status: StagedFileStatus.uploaded,
      remoteUrl: e.url,
      mimeType: e.isImage ? 'image/jpeg' : 'application/pdf',
      uploadedBy: e.uploadedByName,
      uploadedAt: e.uploadedAt,
      reviewerNote: e.reviewerNote,
    );
  }

  // ── Factory: from local pick ──────────────────────────────────────────────

  /// Creates a locally staged file from a file path and mime type.
  ///
  /// Uses current microsecond timestamp as a unique local ID.
  factory StagedFile.local({
    required String localPath,
    required String name,
    required String mimeType,
  }) {
    return StagedFile(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      type: mimeType.startsWith('image/') ? 'image' : 'pdf',
      status: StagedFileStatus.local,
      localPath: localPath,
      mimeType: mimeType,
    );
  }

  /// [uploadProgress] is intentionally excluded from [props].
  /// Progress updates are high-frequency and should NOT trigger Equatable
  /// equality checks — the upload sheet reacts to stream events instead.
  @override
  List<Object?> get props => [
        id,
        name,
        type,
        status,
        localPath,
        remoteUrl,
        mimeType,
        // uploadProgress excluded — high-frequency, not identity-relevant
        errorMessage,
        uploadedBy,
        uploadedAt,
        reviewerNote,
      ];
}
