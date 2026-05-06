import 'dart:async';

import 'package:flutter/material.dart';

/// Reloj que se actualiza cada segundo (anti-screenshot).
class LiveClock extends StatefulWidget {
  final TextStyle? style;
  final bool showSeconds;
  const LiveClock({super.key, this.style, this.showSeconds = true});

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late Timer _t;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final txt = widget.showSeconds
        ? '${_pad(_now.hour)}:${_pad(_now.minute)}:${_pad(_now.second)}'
        : '${_pad(_now.hour)}:${_pad(_now.minute)}';
    return Text(txt, style: widget.style);
  }
}
