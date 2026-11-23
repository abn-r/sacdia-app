import 'package:equatable/equatable.dart';

/// A club the member can move to: its name, its church and the section of the
/// member's club type ([sectionId] is null when the club has none).
class TransferClubOption extends Equatable {
  final int clubId;
  final String name;
  final String? churchName;
  final int? sectionId;

  const TransferClubOption({
    required this.clubId,
    required this.name,
    this.churchName,
    this.sectionId,
  });

  bool get isAvailable => sectionId != null;

  @override
  List<Object?> get props => [clubId, name, churchName, sectionId];
}
