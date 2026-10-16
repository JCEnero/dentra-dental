import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import 'onboarding_palette.dart';
import 'onboarding_progress_indicator.dart';

/// Bottom controls: pagination on the left; on the right, a ghost Back
/// button and a white circular Next button that expands into a
/// "Get Started" pill on the final slide.
class OnboardingControls extends StatelessWidget {
  const OnboardingControls({
    super.key,
    required this.slideCount,
    required this.currentIndex,
    required this.finalLabel,
    required this.onNext,
    required this.onBack,
    required this.isBusy,
    this.isPrimaryLoading = false,
  });

  final int slideCount;
  final int currentIndex;

  /// Label the primary button expands to on the final slide.
  final String finalLabel;
  final VoidCallback onNext;
  final VoidCallback onBack;

  /// True while onboarding is exiting. Disables every action.
  final bool isBusy;

  /// Shows a spinner in the primary button (when it triggered the exit).
  final bool isPrimaryLoading;

  static const double _buttonSize = 56;
  static const double _gap = 12;

  bool get _isLast => currentIndex == slideCount - 1;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 360);
    final showBack = currentIndex > 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Leave room for the pagination (~60) and the back button.
        final pillWidth = (constraints.maxWidth - 60 - _buttonSize - _gap * 2)
            .clamp(_buttonSize, 220.0);

        return Row(
          children: [
            OnboardingProgressIndicator(
              count: slideCount,
              current: currentIndex,
            ),
            const Spacer(),
            AnimatedOpacity(
              opacity: showBack ? 1 : 0,
              duration: duration,
              child: IgnorePointer(
                ignoring: !showBack,
                child: ExcludeSemantics(
                  excluding: !showBack,
                  child: _GhostCircleButton(
                    size: _buttonSize,
                    onTap: isBusy ? null : onBack,
                  ),
                ),
              ),
            ),
            const SizedBox(width: _gap),
            _PrimaryMorphButton(
              size: _buttonSize,
              expandedWidth: pillWidth,
              expanded: _isLast,
              label: finalLabel,
              loading: isPrimaryLoading,
              duration: duration,
              onTap: isBusy ? null : onNext,
            ),
          ],
        );
      },
    );
  }
}

class _GhostCircleButton extends StatelessWidget {
  const _GhostCircleButton({required this.size, required this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Previous slide',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: CircleBorder(
          side: BorderSide(
            color: AppColors.white.withValues(alpha: 0.55),
            width: 1.4,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 22,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// White circle with a teal arrow that morphs into a wide pill with a label.
class _PrimaryMorphButton extends StatelessWidget {
  const _PrimaryMorphButton({
    required this.size,
    required this.expandedWidth,
    required this.expanded,
    required this.label,
    required this.loading,
    required this.duration,
    required this.onTap,
  });

  final double size;
  final double expandedWidth;
  final bool expanded;
  final String label;
  final bool loading;
  final Duration duration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const ink = OnboardingPalette.base;

    final Widget content;
    if (loading) {
      content = const SizedBox.square(
        key: ValueKey('loading'),
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(ink),
        ),
      );
    } else if (expanded) {
      content = Padding(
        key: const ValueKey('label'),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: ink,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 20, color: ink),
            ],
          ),
        ),
      );
    } else {
      content = const Icon(
        Icons.arrow_forward_rounded,
        key: ValueKey('arrow'),
        size: 24,
        color: ink,
      );
    }

    return Semantics(
      button: true,
      label: expanded ? label : 'Next slide',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        width: expanded ? expandedWidth : size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: OnboardingPalette.shadow.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: AnimatedSwitcher(
                duration: duration,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
