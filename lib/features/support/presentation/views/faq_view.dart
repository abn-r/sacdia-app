import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../domain/entities/faq_item.dart';
import '../providers/support_providers.dart';

/// Lista de preguntas frecuentes con búsqueda + expansión inline.
class FaqView extends ConsumerStatefulWidget {
  const FaqView({super.key});

  static const String routeName = '/settings/support/faq';

  @override
  ConsumerState<FaqView> createState() => _FaqViewState();
}

class _FaqViewState extends ConsumerState<FaqView> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync = ref.watch(filteredFaqItemsProvider);

    return Scaffold(
      appBar: AppBar(title: Text('support.faq_title'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ref.read(faqSearchQueryProvider.notifier).state = v,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'support.faq_search_hint'.tr(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(faqSearchQueryProvider.notifier).state = '';
                          FocusScope.of(context).unfocus();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: filteredAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, _) => _FaqError(message: e.toString()),
              data: (items) => items.isEmpty
                  ? _FaqEmpty(query: _searchCtrl.text)
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) => _FaqTile(item: items[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item});
  final FaqItem item;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      leading: const HugeIcon(
        icon: HugeIcons.strokeRoundedQuestion,
        color: Colors.blueGrey,
        size: 22,
      ),
      title: Text(
        item.question,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      children: [
        // flutter_markdown renderiza negritas, listas y saltos dobles.
        MarkdownBody(
          data: item.answer,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _FaqEmpty extends StatelessWidget {
  const _FaqEmpty({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedSearch01,
              color: Colors.black26,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'support.faq_empty'.tr()
                  : 'support.faq_no_results'.tr(args: [query]),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqError extends StatelessWidget {
  const _FaqError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
