class MyActivityRsvp {
  final String? status;
  final bool eligible;

  const MyActivityRsvp({required this.status, required this.eligible});

  factory MyActivityRsvp.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    return MyActivityRsvp(
      status: status is String && status.isNotEmpty ? status : null,
      eligible: json['eligible'] == true,
    );
  }
}

class AttendanceRosterMember {
  final String userId;
  final String name;
  final String? imageUrl;
  final String? rsvp;
  final bool confirmed;

  const AttendanceRosterMember({
    required this.userId,
    required this.name,
    required this.imageUrl,
    required this.rsvp,
    required this.confirmed,
  });

  factory AttendanceRosterMember.fromJson(Map<String, dynamic> json) {
    final rsvp = json['rsvp'];
    return AttendanceRosterMember(
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imageUrl: json['user_image'] as String?,
      rsvp: rsvp is String && rsvp.isNotEmpty ? rsvp : null,
      confirmed: json['confirmed'] == true,
    );
  }
}
