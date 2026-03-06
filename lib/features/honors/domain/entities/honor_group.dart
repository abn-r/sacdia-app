import 'package:equatable/equatable.dart';
import 'honor.dart';
import 'honor_category.dart';

/// Entidad de grupo de especialidades por categoría
class HonorGroup extends Equatable {
  final HonorCategory category;
  final List<Honor> honors;

  const HonorGroup({required this.category, required this.honors});

  @override
  List<Object?> get props => [category, honors];
}
