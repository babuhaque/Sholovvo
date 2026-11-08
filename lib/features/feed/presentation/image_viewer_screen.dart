import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Full-screen swipeable image viewer with pinch-to-zoom and a save-to-gallery
/// action.
///
/// Opens via [ImageViewerScreen.route] and is dismissed by tapping the close
/// button or swiping back system gesture. When multiple images are supplied the
/// user swipes horizontally to navigate between them; each page supports
/// independent zoom via [InteractiveViewer]. The download button saves the
/// image currently in view to the device gallery (a browser download on web).
class ImageViewerScreen extends ConsumerStatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.urls,
    this.initialIndex = 0,
    this.semanticLabel,
  });

  final List<String> urls;
  final int initialIndex;

  /// Accessibility label spoken by screen readers instead of the raw URL.
  final String? semanticLabel;

  /// Returns a [Route] that presents the given [urls] full-screen.
  static Route<void> route(
    List<String> urls, {
    int initialIndex = 0,
    String? semanticLabel,
  }) {
    return FadeSlidePageRoute<void>(
      page: ImageViewerScreen(
        urls: urls,
        initialIndex: initialIndex,
        semanticLabel: semanticLabel,
      ),
    );
  }

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  late final PageController _pageController;
  late int _currentPage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Saves the image currently in view to the device gallery and reports the
  /// outcome in a snackbar. A tap while a save is in flight is ignored rather
  /// than queued, so two taps cannot race two writes for the same photo.
  Future<void> _download() async {
    if (_isSaving) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final String url = widget.urls[_currentPage];

    setState(() => _isSaving = true);
    final Result<void> result = await ref
        .read(gallerySaverProvider)
        .saveImageFromUrl(url);
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);

    final String message = switch (result) {
      Success<void>() => l10n.feedImageDownloaded,
      FailureResult<void>(:final failure) => switch (failure) {
        PermissionFailure() => l10n.feedImageDownloadDenied,
        NetworkFailure() => l10n.feedImageDownloadFailed,
        _ => l10n.feedImageDownloadFailed,
      },
    };
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool hasMultiple = widget.urls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Swipeable image pages.
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (int index) => setState(() => _currentPage = index),
            itemBuilder: (BuildContext context, int index) {
              return InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    widget.urls[index],
                    fit: BoxFit.contain,
                    semanticLabel: widget.semanticLabel,
                    errorBuilder:
                        (BuildContext context, Object error, StackTrace? _) =>
                            const Icon(
                              Icons.broken_image_outlined,
                              size: 64,
                              color: Colors.white54,
                            ),
                    loadingBuilder:
                        (
                          BuildContext context,
                          Widget child,
                          ImageChunkEvent? progress,
                        ) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                            ),
                          );
                        },
                  ),
                ),
              );
            },
          ),
          // Page indicator (only for multi-image posts).
          if (hasMultiple)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: AppRadius.mdRadius,
                    ),
                    child: Text(
                      '${_currentPage + 1} / ${widget.urls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),
          // Close and download controls.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (_isSaving)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                      ),
                      tooltip: l10n.feedImageDownload,
                      onPressed: widget.urls.isEmpty ? null : _download,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
