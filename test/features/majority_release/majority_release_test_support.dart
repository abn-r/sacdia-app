import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncValue;
import 'package:dartz/dartz.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_status.dart';
import 'package:sacdia_app/features/legal/domain/repositories/legal_repository.dart';
import 'package:sacdia_app/features/majority_release/domain/entities/adult_claim_code.dart';
import 'package:sacdia_app/features/majority_release/domain/entities/released_entry.dart';
import 'package:sacdia_app/features/majority_release/domain/repositories/majority_release_repository.dart';

const legalStatusFixture = LegalStatus(
  requiresAcceptance: true,
  documents: [
    LegalDocumentStatus(
      documentType: LegalDocumentTypes.terms,
      version: '2.0.0-family',
      url: 'https://example.com/terms',
      accepted: false,
    ),
    LegalDocumentStatus(
      documentType: LegalDocumentTypes.privacy,
      version: '2.0.0-family',
      url: 'https://example.com/privacy',
      accepted: false,
    ),
  ],
);

UserEntity releasedUser({
  bool frozen = false,
  bool needsAcceptance = true,
  bool needsEmail = false,
  DateTime? deadline,
  DateTime? frozenAt,
}) =>
    UserEntity(
      id: 'u1',
      email: needsEmail ? null : 'u1@example.com',
      name: 'Ana',
      postRegisterComplete: true,
      serverMode: AccountMode.released,
      principal: PrincipalInfo(
        kind: PrincipalKind.releasedUser,
        release: ReleaseInfo(
          status: frozen ? ReleaseStatus.frozen : ReleaseStatus.pending,
          deadlineAt: deadline,
          frozenAt: frozenAt,
          needsAcceptance: needsAcceptance,
          needsEmail: needsEmail,
        ),
      ),
      familyFeatures: const FamilyFeatures(majorityRelease: true),
      authorization: const AuthorizationSnapshot(effectivePermissions: []),
    );

/// Sustituye a [AuthNotifier]: devuelve [user] y cuenta los refrescos.
class RecordingAuth extends AuthNotifier {
  RecordingAuth(this.user);

  UserEntity? user;
  int refreshes = 0;
  int signOuts = 0;

  @override
  Future<UserEntity?> build() async => user;

  void emit(UserEntity? next) => state = AsyncValue<UserEntity?>.data(next);

  @override
  Future<bool> refreshAuthorization({
    Duration minInterval = const Duration(seconds: 30),
  }) async {
    refreshes++;
    return false;
  }

  @override
  Future<bool> signOut() async {
    signOuts++;
    return true;
  }

  @override
  Future<bool> refreshSupervision({Duration? minInterval}) async => false;
}

class FakeLegalRepository implements LegalRepository {
  Either<Failure, LegalStatus> acceptResult = const Right(legalStatusFixture);
  final accepts = <({String terms, String privacy})>[];

  @override
  Future<Either<Failure, LegalStatus>> accept({
    required String termsVersion,
    required String privacyVersion,
  }) async {
    accepts.add((terms: termsVersion, privacy: privacyVersion));
    return acceptResult;
  }

  @override
  Future<Either<Failure, List<LegalDocument>>> getCurrentDocuments() async =>
      const Right([]);

  @override
  Future<Either<Failure, LegalStatus>> getMyStatus() async =>
      const Right(legalStatusFixture);
}

class FakeMajorityReleaseRepository implements MajorityReleaseRepository {
  Either<Failure, void> emailResult = const Right(null);
  Either<Failure, void> redeemResult = const Right(null);
  Either<Failure, List<ReleasedEntry>> history = const Right([]);
  Either<Failure, IssuedAdultClaimCode> guardianCode = Right(
    IssuedAdultClaimCode(
      code: 'AB12-CD34',
      expiresAt: DateTime.utc(2026, 12, 1, 12),
    ),
  );
  Either<Failure, IssuedAdultClaimCode> directorCode = Right(
    IssuedAdultClaimCode(
      code: 'ZZ99-YY88',
      expiresAt: DateTime.utc(2026, 12, 1, 12),
    ),
  );

  final emails = <String>[];
  final redeems = <({String code, String email, String password})>[];
  final guardianIssues = <String>[];
  final directorIssues = <({int section, String user})>[];

  @override
  Future<Either<Failure, void>> addEmail(String email) async {
    emails.add(email);
    return emailResult;
  }

  @override
  Future<Either<Failure, void>> redeemAdultClaim({
    required String code,
    required String email,
    required String password,
  }) async {
    redeems.add((code: code, email: email, password: password));
    return redeemResult;
  }

  @override
  Future<Either<Failure, List<ReleasedEntry>>> getReleasedHistory() async =>
      history;

  @override
  Future<Either<Failure, IssuedAdultClaimCode>> issueGuardianCode(
    String dependentId,
  ) async {
    guardianIssues.add(dependentId);
    return guardianCode;
  }

  @override
  Future<Either<Failure, IssuedAdultClaimCode>> issueDirectorCode({
    required int clubSectionId,
    required String dependentUserId,
  }) async {
    directorIssues.add((section: clubSectionId, user: dependentUserId));
    return directorCode;
  }
}
