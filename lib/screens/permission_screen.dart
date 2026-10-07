import 'package:flutter/material.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({
    super.key,
    required this.isLoading,
    required this.onRequestAccess,
    required this.onOpenSettings,
  });

  final bool isLoading;
  final VoidCallback onRequestAccess;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0x1F9AE7D5),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.video_library_rounded,
                      size: 44,
                      color: Color(0xFF9AE7D5),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Your videos,\nyour device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 31,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Allow gallery access to build your vertical feed. Videos play from local storage only—nothing is uploaded, and no internet connection is required.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      height: 1.55,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isLoading ? null : onRequestAccess,
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_outlined),
                      label: Text(isLoading ? 'Checking access…' : 'Grant video access'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: const Color(0xFF9AE7D5),
                        foregroundColor: const Color(0xFF08211B),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: isLoading ? null : onOpenSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Open app settings'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
