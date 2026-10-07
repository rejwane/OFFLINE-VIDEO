import 'dart:io';

import 'package:flutter/material.dart';

import '../models/creator_profile.dart';

class ActionRail extends StatelessWidget {
  const ActionRail({
    super.key,
    required this.creator,
    required this.isFavorite,
    required this.isMuted,
    required this.playbackSpeed,
    required this.onOpenProfile,
    required this.onToggleFavorite,
    required this.onToggleMute,
    required this.onSpeedChanged,
    required this.onShare,
  });

  final CreatorProfile? creator;
  final bool isFavorite;
  final bool isMuted;
  final double playbackSpeed;
  final VoidCallback onOpenProfile;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProfileAction(creator: creator, onTap: onOpenProfile),
        const SizedBox(height: 15),
        _RoundAction(
          icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: isFavorite ? 'Liked' : 'Like',
          color: isFavorite ? const Color(0xFFFF476F) : Colors.white,
          onTap: onToggleFavorite,
        ),
        const SizedBox(height: 15),
        _RoundAction(
          icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          label: isMuted ? 'Muted' : 'Sound',
          onTap: onToggleMute,
        ),
        const SizedBox(height: 15),
        _SpeedAction(speed: playbackSpeed, onSpeedChanged: onSpeedChanged),
        const SizedBox(height: 15),
        _RoundAction(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: onShare,
        ),
      ],
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({required this.creator, required this.onTap});

  final CreatorProfile? creator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarPath = creator?.avatarPath;
    final avatarExists = avatarPath != null && File(avatarPath).existsSync();

    return Semantics(
      button: true,
      label: creator == null ? 'Choose a creator profile' : 'Open ${creator!.name} profile',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            children: [
              Container(
                width: 49,
                height: 49,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF9AE7D5), width: 1.5),
                  color: const Color(0xAA15191F),
                ),
                child: ClipOval(
                  child: avatarExists
                      ? Image.file(File(avatarPath!), fit: BoxFit.cover)
                      : Icon(
                          creator == null
                              ? Icons.person_add_alt_1_rounded
                              : Icons.person_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                creator?.name ?? 'Profile',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedAction extends StatelessWidget {
  const _SpeedAction({required this.speed, required this.onSpeedChanged});

  final double speed;
  final ValueChanged<double> onSpeedChanged;

  static const List<double> _speeds = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      initialValue: speed,
      onSelected: onSpeedChanged,
      color: const Color(0xFF20242B),
      itemBuilder: (context) => _speeds
          .map(
            (value) => PopupMenuItem<double>(
              value: value,
              child: Row(
                children: [
                  if (value == speed)
                    const Icon(Icons.check_rounded, size: 18, color: Color(0xFF9AE7D5))
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text('${value}x'),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xAA15191F),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.speed_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 5),
            Text(
              '${speed}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xAA15191F),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
