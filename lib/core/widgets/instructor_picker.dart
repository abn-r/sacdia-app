import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import 'instructor_candidates_provider.dart';
import 'instructor_avatar.dart';
import 'instructor_selection.dart';
import 'sac_button.dart';
import 'sac_loading.dart';
import 'sac_pressable.dart';
import 'sac_sheet.dart';

/// Sheet to choose an instructor: people of the member's Local Field (name and
/// photo only) or, always at the end, the typed text as a free name for
/// someone from another Local Field or outside SACDIA.
///
/// Searches from 3 characters, debounced; the previous request is cancelled
/// when the text changes. Pops with an [InstructorSelection], or null when
/// dismissed.
class InstructorPicker extends ConsumerStatefulWidget {
  const InstructorPicker({
    super.key,
    this.debounce = const Duration(milliseconds: 300),
  });

  final Duration debounce;

  static Future<InstructorSelection?> show(
    BuildContext context, {
    Duration debounce = const Duration(milliseconds: 300),
  }) {
    return showSacSheet<InstructorSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => InstructorPicker(debounce: debounce),
    );
  }

  @override
  ConsumerState<InstructorPicker> createState() => _InstructorPickerState();
}

class _InstructorPickerState extends ConsumerState<InstructorPicker> {
  final _controller = TextEditingController();
  Timer? _timer;

  /// The text the search runs with, one debounce behind the field.
  String _query = '';

  /// Last answer, kept on screen while the next one loads (no flicker).
  List<InstructorSelection>? _last;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    if (!InstructorRules.isSearchable(text)) {
      // Nothing to ask the API: reflect it now, not 300 ms later.
      setState(() {
        _query = text;
        _last = null;
      });
      return;
    }
    setState(() {});
    _timer = Timer(widget.debounce, () {
      if (mounted) setState(() => _query = text);
    });
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
  }

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  void _onResults(
    AsyncValue<List<InstructorSelection>>? _,
    AsyncValue<List<InstructorSelection>> next,
  ) {
    next.whenData((people) {
      _announce(
        people.isEmpty
            ? 'instructor.no_results_short'.tr()
            : (people.length == 1
                    ? 'instructor.results_one'
                    : 'instructor.results_other')
                .tr(namedArgs: {'count': '${people.length}'}),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SacSheetHeader(title: 'instructor.title'.tr(), showClose: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    InstructorRules.maxNameChars,
                  ),
                ],
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'instructor.search_hint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).deleteButtonTooltip,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(Icons.close),
                          onPressed: _clear,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'instructor.scope_note'.tr(),
                  style: theme.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ),
            ),
            Divider(height: 1, color: c.border),
            Flexible(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final searchable = InstructorRules.isSearchable(_query);
    final rows = <Widget>[];

    if (!searchable) {
      final short = InstructorRules.normalize(_controller.text).length <
          InstructorRules.minSearchChars;
      rows.add(
        _Message(
          (short ? 'instructor.type_min' : 'instructor.keep_typing').tr(),
        ),
      );
    } else {
      ref.listen(instructorCandidatesProvider(_query), _onResults);
      final async = ref.watch(instructorCandidatesProvider(_query));
      if (async.hasValue) _last = async.requireValue;
      final people = _last;
      if (async.hasError) {
        final limited = async.error is InstructorSearchException &&
            (async.error as InstructorSearchException).error ==
                InstructorSearchError.rateLimited;
        rows.add(
          _Message(
            (limited ? 'instructor.rate_limited' : 'instructor.search_error')
                .tr(),
            action: SacButton.ghost(
              text: 'instructor.retry'.tr(),
              onPressed: () =>
                  ref.invalidate(instructorCandidatesProvider(_query)),
            ),
          ),
        );
      } else if (people == null) {
        rows.add(
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: SacLoading()),
          ),
        );
      } else if (people.isEmpty) {
        rows.add(
          _Message(
            'instructor.no_results'.tr(
              namedArgs: {'query': InstructorRules.normalize(_query)},
            ),
          ),
        );
      } else {
        for (final person in people) {
          rows.add(
            _PersonRow(
              person: person,
              onTap: () => Navigator.of(context).pop(person),
            ),
          );
        }
      }
    }

    final typed = InstructorRules.freeName(_controller.text);
    if (typed != null) {
      rows.add(
        _FreeNameRow(
          name: typed,
          onTap: () =>
              Navigator.of(context).pop(InstructorSelection.external(typed)),
        ),
      );
    }
    return ListView(shrinkWrap: true, children: rows);
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: c.textSecondary),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onTap});

  final InstructorSelection person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SacPressable(
      onTap: onTap,
      semanticLabel: person.displayName,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              InstructorAvatar(
                name: person.displayName,
                photoUrl: person.photoUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  person.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: context.sac.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Usar «Ana» como nombre": always last once the text could be a name.
class _FreeNameRow extends StatelessWidget {
  const _FreeNameRow({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    final label = 'instructor.use_as_name'.tr(namedArgs: {'name': name});
    return SacPressable(
      onTap: onTap,
      semanticLabel: '$label. ${'instructor.use_as_name_hint'.tr()}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedUserEdit01,
                    size: 18,
                    color: c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium?.copyWith(color: c.text),
                    ),
                    Text(
                      'instructor.use_as_name_hint'.tr(),
                      style: theme.bodySmall?.copyWith(color: c.textSecondary),
                    ),
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
