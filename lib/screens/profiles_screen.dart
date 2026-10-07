import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/creator_profile.dart';
import '../providers/feed_provider.dart';
import 'creator_profile_screen.dart';
import 'profile_editor_screen.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});

  Future<void> _createProfile(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ProfileEditorScreen()),
    );
  }

  Future<void> _editProfile(BuildContext context, CreatorProfile profile) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileEditorScreen(profile: profile),
      ),
    );
  }

  Future<void> _deleteProfile(BuildContext context, CreatorProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this profile?'),
        content: Text(
          '“${profile.name}” and its local video grouping will be removed. Original videos stay on the device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete profile'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<FeedProvider>().deleteProfile(profile.id);
    }
  }

  void _openProfile(BuildContext context, CreatorProfile profile) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreatorProfileScreen(profileId: profile.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0E),
      appBar: AppBar(
        title: const Text('Local profiles'),
        actions: [
          IconButton(
            tooltip: 'Create profile',
            onPressed: () => _createProfile(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Consumer<FeedProvider>(
        builder: (context, feed, _) {
          if (feed.profiles.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, size: 46, color: Colors.white60),
                    const SizedBox(height: 14),
                    const Text(
                      'Create your first profile',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add a picture and description, then select local videos to group on its profile page.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => _createProfile(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create profile'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
            itemCount: feed.profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final profile = feed.profiles[index];
              final path = profile.avatarPath;
              final hasAvatar = path != null && File(path).existsSync();
              return Card(
                color: const Color(0xFF14171C),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(14, 7, 4, 7),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF282D34),
                    backgroundImage: hasAvatar ? FileImage(File(path!)) : null,
                    child: hasAvatar
                        ? null
                        : const Icon(Icons.person_rounded, color: Colors.white70),
                  ),
                  title: Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    profile.bio.isEmpty
                        ? '${profile.videoIds.length} local videos'
                        : '${profile.bio}\n${profile.videoIds.length} local videos',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openProfile(context, profile),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'edit') _editProfile(context, profile);
                      if (action == 'delete') _deleteProfile(context, profile);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit profile')),
                      PopupMenuItem(value: 'delete', child: Text('Delete profile')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
