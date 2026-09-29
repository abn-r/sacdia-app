import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// [ExpansionTile] whose header scales on press. The body stays still.
class SacExpansionTile extends StatefulWidget {
  const SacExpansionTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.initiallyExpanded = false,
    this.tilePadding,
    this.childrenPadding = EdgeInsets.zero,
    this.children = const <Widget>[],
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry? tilePadding;
  final EdgeInsetsGeometry childrenPadding;
  final List<Widget> children;

  @override
  State<SacExpansionTile> createState() => _SacExpansionTileState();
}

class _SacExpansionTileState extends State<SacExpansionTile> {
  late bool _open = widget.initiallyExpanded;

  @override
  void didUpdateWidget(SacExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded &&
        oldWidget.initiallyExpanded == _open) {
      _open = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SacPressable(
          listenOnly: true,
          child: ExpansionTile(
            enableFeedback: false,
            initiallyExpanded: widget.initiallyExpanded,
            onExpansionChanged: (open) => setState(() => _open = open),
            tilePadding: widget.tilePadding,
            childrenPadding: EdgeInsets.zero,
            leading: widget.leading,
            title: widget.title,
            subtitle: widget.subtitle,
            children: const <Widget>[],
          ),
        ),
        AnimatedSize(
          duration: reduce ? Duration.zero : SacMotion.standard,
          curve: SacMotion.easeOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: widget.childrenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.children,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
