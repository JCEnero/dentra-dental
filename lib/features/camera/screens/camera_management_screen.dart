import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../camera_flow.dart';
import '../camera_strings.dart';
import '../data/saved_camera.dart';
import '../providers/camera_providers.dart';

/// Account-owned cameras on the website, or the saved camera on a phone.
/// Offline cameras stay removable so a lost device secret can be recovered.
class CameraManagementScreen extends ConsumerStatefulWidget {
  const CameraManagementScreen({super.key, this.allowSetup = true});

  final bool allowSetup;

  static Route<void> route({bool allowSetup = true}) => MaterialPageRoute<void>(
        builder: (_) => CameraManagementScreen(allowSetup: allowSetup),
      );

  @override
  ConsumerState<CameraManagementScreen> createState() =>
      _CameraManagementScreenState();
}

class _CameraManagementScreenState
    extends ConsumerState<CameraManagementScreen> {
  String? _removing;

  Future<void> _remove(SavedCamera camera) async {
    if (_removing != null) return;
    final confirmed = await showGlassConfirmDialog(
      context: context,
      icon: Icons.videocam_off_outlined,
      title: CamText.removeCameraTitle(camera.name),
      message: camera.cloudId != null
          ? CamText.removeCameraBody
          : CamText.removeLocalCameraBody,
      confirmLabel: CamText.removeCamera,
      destructive: true,
    );
    if (!confirmed || !mounted || _removing != null) return;
    setState(() => _removing = camera.key);
    try {
      await ref.read(savedCameraProvider.notifier).remove(camera);
      if (mounted) showDentraSnack(context, CamText.cameraRemoved);
    } catch (e) {
      if (mounted) {
        showDentraSnack(
          context,
          e is ApiException ? e.message : CamText.cameraRemoveFailed,
          tone: DentraFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _removing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloud = ref.watch(camLinkProvider) == CamLink.cloud;
    final AsyncValue<List<SavedCamera>> cameras = cloud
        ? ref.watch(cloudCamerasProvider).whenData(
            (items) => items.map((camera) => camera.toSaved()).toList())
        : ref
            .watch(savedCameraProvider)
            .whenData((camera) => camera == null ? [] : [camera]);
    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  DentraPageHeader(
                    title: CamText.manageCameras,
                    onBack: () => Navigator.of(context).pop(),
                    trailing: IconButton(
                      tooltip: 'Refresh cameras',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _removing != null
                          ? null
                          : () => cloud
                              ? ref.invalidate(cloudCamerasProvider)
                              : ref.invalidate(savedCameraProvider),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(cloud
                      ? CamText.cameraLinkExplanation
                      : CamText.cameraLocalExplanation),
                  if (cloud) ...[
                    const SizedBox(height: 12),
                    const Text(CamText.cameraRecoveryHint),
                  ],
                  const SizedBox(height: 24),
                  cameras.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (_, __) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(CamText.camerasLoadFailed),
                        const SizedBox(height: 12),
                        DentraPillButton(
                          label: CamText.retry,
                          onPressed: () => cloud
                              ? ref.invalidate(cloudCamerasProvider)
                              : ref.invalidate(savedCameraProvider),
                        ),
                      ],
                    ),
                    data: (items) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (items.isEmpty) ...[
                          const Text(CamText.noCameras,
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          const Text(CamText.noCamerasBody),
                        ],
                        for (final camera in items) ...[
                          GlassCard(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(camera.name,
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700)),
                                if (camera.host != null) ...[
                                  const SizedBox(height: 6),
                                  Text(camera.host!),
                                ],
                                const SizedBox(height: 16),
                                DentraPillButton(
                                  label: CamText.removeCamera,
                                  icon: Icons.delete_outline_rounded,
                                  variant: DentraButtonVariant.danger,
                                  loading: _removing == camera.key,
                                  onPressed: _removing == null
                                      ? () => _remove(camera)
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const SizedBox(height: 8),
                        if (widget.allowSetup)
                          DentraPillButton(
                            label: CamText.cardSetUp,
                            variant: DentraButtonVariant.outline,
                            onPressed: _removing == null
                                ? () async {
                                    await openCameraSetup(context);
                                    if (mounted && cloud) {
                                      ref.invalidate(cloudCamerasProvider);
                                    }
                                  }
                                : null,
                          ),
                      ],
                    ),
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
