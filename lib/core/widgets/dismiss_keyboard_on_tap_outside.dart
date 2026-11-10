import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Closes the keyboard when the user taps anywhere outside the focused text
/// field, across the whole app.
///
/// Flutter only does this on desktop and web: on Android and iOS a touch
/// outside a field leaves it focused and the keyboard open. Mounted once in
/// `MaterialApp.builder`, this widget overrides the tap-outside intents that
/// every [EditableText] invokes when it has no callback of its own, so it
/// covers `SacTextField`, plain `TextField`s and fields inside sheets and
/// dialogs.
///
/// The field loses focus on pointer up, and only if the pointer stayed within
/// [kTouchSlop] of where it went down: a tap closes the keyboard, a scroll
/// does not.
///
/// To keep the keyboard open while the user taps something outside the field
/// (an accessory bar above the keyboard, a send button), wrap that widget in a
/// [TextFieldTapRegion]. A field that sets its own `onTapUpOutside` keeps it.
class DismissKeyboardOnTapOutside extends StatefulWidget {
  const DismissKeyboardOnTapOutside({super.key, required this.child});

  final Widget child;

  @override
  State<DismissKeyboardOnTapOutside> createState() =>
      _DismissKeyboardOnTapOutsideState();
}

class _DismissKeyboardOnTapOutsideState
    extends State<DismissKeyboardOnTapOutside> {
  // Where the last touch outside a focused field went down, to tell a tap
  // from a drag when it comes up.
  int? _downPointer;
  Offset? _downPosition;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    EditableTextTapOutsideIntent:
        CallbackAction<EditableTextTapOutsideIntent>(onInvoke: _onTapDown),
    EditableTextTapUpOutsideIntent:
        CallbackAction<EditableTextTapUpOutsideIntent>(onInvoke: _onTapUp),
  };

  Object? _onTapDown(EditableTextTapOutsideIntent intent) {
    _downPointer = intent.pointerDownEvent.pointer;
    _downPosition = intent.pointerDownEvent.position;
    return null;
  }

  Object? _onTapUp(EditableTextTapUpOutsideIntent intent) {
    final event = intent.pointerUpEvent;
    final downPosition = _downPosition;
    final isSamePointer = event.pointer == _downPointer;
    _downPointer = null;
    _downPosition = null;

    if (!isSamePointer || downPosition == null) return null;
    if ((event.position - downPosition).distance > kTouchSlop) return null;

    intent.focusNode.unfocus();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Actions(actions: _actions, child: widget.child);
  }
}
