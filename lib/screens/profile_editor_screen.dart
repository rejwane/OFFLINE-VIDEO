import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/creator_profile.dart';
import '../models/video_item.dart';
import '../providers/feed_provider.dart';
import '../widgets/video_thumbnail.dart';
import 'video_selection_screen.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key, this.profile, this.initialVideoId});

  final CreatorProfile? profile;
  final String? initialVideoId;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final Set<String> _selectedVideoIds = <String>{};

  List<VideoItem> _videos = <VideoItem>[];
  String? _avatarPath;
  bool _isLoadingVideos = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController.text = profile?.name ?? '';
    _bioController.text = profile?.bio ?? '';
    _avatarPath = profile?.avatarPath;
    _selectedVideoIds.addAll(profile?.videoIds ?? const <String>[]);
    if (widget.initialVideoId != null) _selectedVideoIds.add(widget.initialVideoId!);
    unawaited(_loadVideos());
  }

  Future<void> _loadVideos() async {
    try {
      final videos = await context.read<FeedProvider>().loadAllLocalVideos();
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _isLoadingVideos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingVideos = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;
      final newPath = await context.read<FeedProvider>().copyProfileAvatar(picked);
      if (!mounted) return;
      setState(() => _avatarPath = newPath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that profile photo.')),
      );
    }
  }

  Future<void> _selectVideos() async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute<Set<String>>(
        builder: (_) => VideoSelectionScreen(
          videos: _videos,
          initialSelection: Set<String>.of(_selectedVideoIds),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedVideoIds
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final profile = CreatorProfile(
      id: widget.profile?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      avatarPath: _avatarPath,
      videoIds: _selectedVideoIds.toList(growable: false),
    );

    try {
      await context.read<FeedProvider>().saveProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the profile. Try again.')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarExists = _avatarPath != null && File(_avatarPath!).existsSync();

    return Scaffold(
      backgroundColor: const Color(0xFF080A0E),
      appBar: AppBar(
        title: Text(widget.profile == null ? 'Create profile' : 'Edit profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => unawaited(_save()),
            child: Text(_isSaving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            Center(
              child: GestureDetector(
                onTap: () => unawaited(_pickAvatar()),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: const Color(0xFF20242B),
                      backgroundImage:
                          avatarExists ? FileImage(File(_avatarPath!)) : null,
                      child: avatarExists
                          ? null
                          : const Icon(Icons.person_rounded, size: 48, color: Colors.white70),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF9AE7D5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Color(0xFF08211B),
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _nameController,
              maxLength: 32,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Profile name',
                hintText: 'e.g. Travel clips',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Enter a profile name.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bioController,
              maxLength: 120,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description / bio',
                hintText: 'Write a short description…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Videos on this profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isLoadingVideos ? null : () => unawaited(_selectVideos()),
                  icon: const Icon(Icons.video_collection_outlined, size: 18),
                  label: const Text('Select'),
                ),
              ],
            ),
            Text(
              _isLoadingVideos
                  ? 'Scanning local videos…'
                  : '${_selectedVideoIds.length} selected. Assigned videos also stay in For You.',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_selectedVideoIds.isNotEmpty && !_isLoadingVideos)
              SizedBox(
                height: 108,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _videos
                      .where((video) => _selectedVideoIds.contains(video.id))
                      .take(12)
                      .map(
                        (video) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 72,
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: VideoThumbnail(asset: video.asset),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  video.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : () => unawaited(_save()),
                icon: const Icon(Icons.check_rounded),
                label: Text(_isSaving ? 'Saving…' : 'Save local profile'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
