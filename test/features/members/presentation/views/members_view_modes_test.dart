import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/presentation/views/members_view.dart';

/// Join requests and annual continuations answer 403 without
/// club_members:approve, so a counselor only gets the member list.
void main() {
  test('without approve permission only the member list is shown', () {
    expect(effectiveMembersMode(1, canApprove: false), 0);
    expect(effectiveMembersMode(2, canApprove: false), 0);
  });

  test('with approve permission the chosen mode stays', () {
    expect(effectiveMembersMode(1, canApprove: true), 1);
    expect(effectiveMembersMode(2, canApprove: true), 2);
  });
}
