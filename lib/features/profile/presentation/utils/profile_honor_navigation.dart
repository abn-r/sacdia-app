import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/utils/honor_work_navigation.dart';

/// Resolves the best destination when opening an enrolled honor from Profile.
///
/// Same resume rules as catalog and post-enroll: in-app → requirements,
/// external → evidence, undecided/completed → detail.
String profileHonorDestinationPath(UserHonor userHonor) =>
    honorWorkDestinationPath(userHonor);
