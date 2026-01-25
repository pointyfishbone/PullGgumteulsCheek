import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:gti_speaki/game/ggumteul_game.dart';

class PullCounter extends StatefulWidget {
  final GgumteulGame game;

  const PullCounter({super.key, required this.game});

  @override
  State<PullCounter> createState() => _PullCounterState();
}

class _PullCounterState extends State<PullCounter> {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();

    _ticker = Ticker((_) {
      if (mounted) {
        setState(() {});
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          'CUTE: ${widget.game.pullCount}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
