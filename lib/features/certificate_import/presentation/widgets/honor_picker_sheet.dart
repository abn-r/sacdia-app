import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_category.dart';
import 'package:sacdia_app/features/honors/domain/usecases/get_honors.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_badge_image.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_category_chip.dart';

import '../error/certificate_import_error_mapper.dart';

/// Honor search sheet: the search box starts with the name the OCR read, so
/// results show up before typing. Category chips narrow the list.
///
/// The API ignores a search shorter than 2 characters, so the sheet only
/// queries with 2 to 60 characters or with a category (never the whole
/// catalog). Typing is debounced by [debounce].
class HonorPickerSheet extends ConsumerStatefulWidget {
  const HonorPickerSheet({
    super.key,
    this.initialQuery = '',
    this.initialCategoryId,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String initialQuery;
  final int? initialCategoryId;
  final Duration debounce;

  /// Opens the sheet; returns the chosen honor or null when dismissed.
  static Future<Honor?> show(
    BuildContext context, {
    String initialQuery = '',
    int? categoryId,
  }) {
    return showSacSheet<Honor>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HonorPickerSheet(
        initialQuery: initialQuery,
        initialCategoryId: categoryId,
      ),
    );
  }

  @override
  ConsumerState<HonorPickerSheet> createState() => _HonorPickerSheetState();
}

class _HonorPickerSheetState extends ConsumerState<HonorPickerSheet> {
  static const _minChars = 2;
  static const _maxChars = 60;

  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  CancelToken? _cancel;
  late int? _categoryId = widget.initialCategoryId;
  List<Honor>? _results;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancel?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String? get _search {
    final q = _controller.text.trim();
    if (q.length < _minChars) return null;
    return q.length > _maxChars ? q.substring(0, _maxChars) : q;
  }

  bool get _canQuery => _search != null || _categoryId != null;

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, _load);
    setState(() {});
  }

  Future<void> _load() async {
    _cancel?.cancel();
    if (!_canQuery) {
      setState(() {
        _results = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    final token = _cancel = CancelToken();
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(getHonorsProvider)(
      GetHonorsParams(categoryId: _categoryId, search: _search),
      cancelToken: token,
    );
    if (!mounted || token.isCancelled) return;
    setState(() {
      _loading = false;
      result.fold((failure) => _error = failure, (honors) => _results = honors);
    });
  }

  void _pickCategory(int? id) {
    setState(() => _categoryId = id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final categories = ref.watch(honorCategoriesProvider).valueOrNull ??
        const <HonorCategory>[];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SacSheetHeader(
              title: 'certificate_import.picker.honor_title'.tr(),
              showClose: true,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'certificate_import.picker.search_hint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .deleteButtonTooltip,
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        ),
                ),
              ),
            ),
            if (categories.isNotEmpty)
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: [
                    for (final category in [null, ...categories]) ...[
                      HonorCategoryChip(
                        label: category?.name ??
                            'certificate_import.picker.all_categories'.tr(),
                        isSelected: _categoryId == category?.id,
                        activeColor: category == null
                            ? null
                            : getCategoryColor(
                                categoryId: category.id,
                                categoryName: category.name,
                              ),
                        onTap: () => _pickCategory(category?.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            Divider(height: 1, color: c.border),
            Flexible(child: _body(context, categories)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<HonorCategory> categories) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    Widget message(String text, {Widget? action}) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text,
                  textAlign: TextAlign.center,
                  style: theme.bodyMedium?.copyWith(color: c.textSecondary)),
              if (action != null) action,
            ],
          ),
        );

    if (_error != null) {
      return message(
        CertificateImportErrorMapper.message(_error),
        action: SacButton.ghost(
          text: 'certificate_import.errors.retry'.tr(),
          onPressed: _load,
        ),
      );
    }
    if (!_canQuery) {
      return message('certificate_import.picker.type_to_search'.tr());
    }
    final results = _results;
    if (_loading && results == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: SacLoading()),
      );
    }
    if (results == null) return const SizedBox.shrink();
    if (results.isEmpty) {
      final category = categories
          .where((cat) => cat.id == _categoryId)
          .map((cat) => cat.name)
          .firstOrNull;
      final query = _search ?? '';
      return message(
        (category == null
                ? 'certificate_import.picker.no_results'
                : 'certificate_import.picker.no_results_in')
            .tr(namedArgs: {'query': query, 'category': category ?? ''}),
        action: category == null
            ? null
            : SacButton.ghost(
                text: 'certificate_import.picker.search_all'.tr(),
                onPressed: () => _pickCategory(null),
              ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: results.length,
      itemBuilder: (context, index) => _HonorRow(
        honor: results[index],
        onTap: () => Navigator.of(context).pop(results[index]),
      ),
    );
  }
}

class _HonorRow extends StatelessWidget {
  const _HonorRow({required this.honor, required this.onTap});

  final Honor honor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    return SacPressable(
      onTap: onTap,
      semanticLabel: honor.categoryName == null
          ? honor.name
          : '${honor.name}, ${honor.categoryName}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              HonorBadgeImage(
                imageUrl: honor.imageUrl,
                width: 36,
                height: 36,
                fallbackColor: c.textSecondary,
                fallbackBackgroundColor: c.surfaceVariant,
                fallbackIconSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(honor.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyMedium?.copyWith(color: c.text)),
                    if (honor.categoryName != null)
                      Text(honor.categoryName!,
                          style: theme.bodySmall
                              ?.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category sheet. Returns `(id: null)` for "Todas las categorías" and null
/// when dismissed, so clearing the filter is not confused with cancelling.
Future<({int? id})?> showHonorCategoryPicker(
  BuildContext context, {
  required List<HonorCategory> categories,
  required int? selectedId,
}) {
  return showSacSheet<({int? id})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final c = sheetContext.sac;
      Widget tile(String label, int? id, Color? dot) => ListTile(
            minVerticalPadding: 12,
            leading: dot == null
                ? const SizedBox(width: 12)
                : Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
            title: Text(label),
            trailing: id == selectedId
                ? HugeIcon(
                    icon: HugeIcons.strokeRoundedTick02,
                    size: 20,
                    color: c.text,
                  )
                : null,
            onTap: () => Navigator.of(sheetContext).pop((id: id)),
          );
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SacSheetHeader(
              title: 'certificate_import.picker.category_title'.tr(),
              showClose: true,
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  tile('certificate_import.picker.all_categories'.tr(), null,
                      null),
                  for (final category in categories)
                    tile(
                      category.name,
                      category.id,
                      getCategoryColor(
                        categoryId: category.id,
                        categoryName: category.name,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
