import 'dart:math' as math;

import 'package:flutter/material.dart';

class ProgressBar extends StatefulWidget {
  const ProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  double? _dragPositionMs;

  @override
  Widget build(BuildContext context) {
    final durationMs = math.max(1, widget.duration.inMilliseconds);
    final positionMs = (_dragPositionMs ?? widget.position.inMilliseconds.toDouble())
        .clamp(0.0, durationMs.toDouble())
        .toDouble();
    final canSeek = widget.duration.inMilliseconds > 0;

    return Row(
      children: [
        SizedBox(
          width: 38,
          child: Text(
            _formatDuration(widget.position),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              activeTrackColor: const Color(0xFF9AE7D5),
              inactiveTrackColor: Colors.white38,
              thumbColor: Colors.white,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              min: 0,
              max: durationMs.toDouble(),
              value: positionMs,
              onChanged: canSeek
                  ? (value) => setState(() => _dragPositionMs = value)
                  : null,
              onChangeEnd: canSeek
                  ? (value) {
                      setState(() => _dragPositionMs = null);
                      widget.onSeek(Duration(milliseconds: value.round()));
                    }
                  : null,
            ),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            _formatDuration(widget.duration),
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
