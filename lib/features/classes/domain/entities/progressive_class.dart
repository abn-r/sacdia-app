import 'package:equatable/equatable.dart';

/// Entidad de clase progresiva del dominio
class ProgressiveClass extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int clubTypeId;
  final String? imageUrl;

  const ProgressiveClass({
    required this.id,
    required this.name,
    this.description,
    required this.clubTypeId,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [id, name, description, clubTypeId, imageUrl];
}
