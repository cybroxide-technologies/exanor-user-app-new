import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/models/coupon_models.dart';
import 'package:exanor/services/coupon_service.dart';

class ExternalCouponCarousel extends StatefulWidget {
  final TabController? controller;

  const ExternalCouponCarousel({super.key, this.controller});

  @override
  State<ExternalCouponCarousel> createState() => _ExternalCouponCarouselState();
}

class _ExternalCouponCarouselState extends State<ExternalCouponCarousel>
    with WidgetsBindingObserver {
  List<ExternalCoupon> _coupons = [];
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;

  // Video playback logic
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  bool _isYoutubeVideo = false;
  bool _isMuted = true; // Default to muted

  Timer? _playbackTimer;
  bool _isVideoInitialized = false;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller != null) {
      _tabController = widget.controller;
      _tabController?.addListener(_onTabChanged);
    }
    _fetchCoupons();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Use passed controller if available, otherwise listen to DefaultTabController
    if (widget.controller != null) return;

    final newTabController = DefaultTabController.of(context);
    if (newTabController != _tabController) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = newTabController;
      _tabController?.addListener(_onTabChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController?.removeListener(_onTabChanged);
    _cancelPlaybackTimer();
    _disposeControllers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopPlayback();
    } else if (state == AppLifecycleState.resumed) {
      if (_tabController != null && _tabController!.index == 2) {
        _checkAndStartTimer(_currentIndex);
      }
    }
  }

  void _onTabChanged() {
    if (_tabController == null) return;

    // Debug logic for troubleshooting
    // debugPrint("Tab Changed: Index ${_tabController!.index}, Changing: ${_tabController!.indexIsChanging}");

    if (_tabController!.index == 2) {
      // If we are on the Offers tab, start/restart check
      // We don't filter by indexIsChanging to ensure we catch all entry events
      _checkAndStartTimer(_currentIndex);
    } else {
      _stopPlayback();
    }
  }

  void _stopPlayback() {
    _cancelPlaybackTimer();
    _disposeControllers();
    if (mounted) {
      if (_isVideoInitialized) {
        setState(() {
          _isVideoInitialized = false;
          _isYoutubeVideo = false;
        });
      }
    }
  }

  Future<void> _fetchCoupons() async {
    try {
      final response = await CouponService.getExternalCoupons(
        query: {'is_enabled': true},
        pageSize: 5,
      );
      if (mounted) {
        setState(() {
          _coupons = response.coupons;
          _isLoading = false;
        });
        // Initial check
        if (_coupons.isNotEmpty) {
          _checkAndStartTimer(0);
        }
      }
    } catch (e) {
      debugPrint("Error fetching coupons: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onPageChanged(int index, CarouselPageChangedReason reason) {
    // 1. Immediately stop current playback and reset state to show image
    _resetVideoState();

    setState(() {
      _currentIndex = index;
    });

    // 2. Start timer for the NEW index
    _checkAndStartTimer(index);
  }

  // Separate method just for state reset (UI update + disposal)
  void _resetVideoState() {
    _cancelPlaybackTimer();
    _disposeControllers();
    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
        _isYoutubeVideo = false;
        _videoController = null;
        _youtubeController = null;
      });
    }
  }

  void _disposeControllers() {
    try {
      _videoController?.pause();
      _videoController?.dispose();
    } catch (_) {}
    _videoController = null;

    try {
      _youtubeController?.pause();
      _youtubeController?.dispose();
    } catch (_) {}
    _youtubeController = null;

    // Note: We don't verify mounted here as this might be called during dispose
  }

  void _cancelPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
  }

  void _checkAndStartTimer(int index) {
    _cancelPlaybackTimer();

    // Since we now strictly reset on page change, we don't need complex "is playing" checks here.
    // If this method is called, it means we WANT to start the timer for 'index'.

    // Verification logic:
    // 1. Must have coupons
    // 2. Coupon must have video URL
    if (_coupons.isEmpty || index >= _coupons.length) return;
    final url = _coupons[index].videoUrl;
    if (url.isEmpty) {
      return;
    }

    // 3. Must be on the correct Tab (if applicable)
    if (_tabController != null && _tabController!.index != 2) {
      return;
    }

    debugPrint("Starting 3s timer for index $index with video: $url");

    // Start 3-second timer
    _playbackTimer = Timer(const Duration(seconds: 3), () {
      _playVideo(index);
    });
  }

  Future<void> _playVideo(int index) async {
    if (!mounted) return;

    // Double check conditions before playing
    if (_tabController != null && _tabController!.index != 2) return;
    if (index != _currentIndex) return;

    final coupon = _coupons[index];
    if (coupon.videoUrl.isEmpty) return;

    debugPrint("Attempting to play video for coupon ${coupon.id}");
    debugPrint("Video URL: ${coupon.videoUrl}");

    // Reset mute state to true for new video
    if (mounted) {
      setState(() {
        _isMuted = true;
      });
    }

    // Check if it's a YouTube URL
    final videoId = YoutubePlayer.convertUrlToId(coupon.videoUrl);
    final isYoutube = videoId != null;
    debugPrint("Is YouTube: $isYoutube, Video ID: $videoId");

    try {
      if (isYoutube) {
        final newController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: true, // Start muted
            loop: true,
            hideControls: true,
            enableCaption: false,
          ),
        );

        // Critical: Check if user swiped away while we were initializing
        if (!mounted || _currentIndex != index) {
          newController.dispose();
          return;
        }

        setState(() {
          _youtubeController = newController;
          _isYoutubeVideo = true;
          _isVideoInitialized = true;
        });
      } else {
        // Standard video player logic
        final newController = VideoPlayerController.networkUrl(
          Uri.parse(coupon.videoUrl),
        );

        await newController.initialize();

        if (!mounted || _currentIndex != index) {
          newController.dispose();
          return;
        }

        if (_tabController != null && _tabController!.index != 2) {
          newController.dispose();
          return;
        }

        // Mute by default
        await newController.setVolume(0.0);
        await newController.play();
        await newController.setLooping(true);

        setState(() {
          _videoController = newController;
          _isYoutubeVideo = false;
          _isVideoInitialized = true;
        });
      }

      debugPrint("Video playing successfully for index $index");
    } catch (e) {
      debugPrint("Error playing video for coupon ${coupon.id}: $e");
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });

    if (_isYoutubeVideo) {
      if (_isMuted) {
        _youtubeController?.mute();
      } else {
        _youtubeController?.unMute();
      }
    } else {
      _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
    }
  }

  void _openCouponDetails(ExternalCoupon coupon) {
    _stopPlayback();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Coupon Details',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ExternalCouponFullScreenPopup(coupon: coupon);
      },
    ).then((_) {
      // Upon returning, restart logic if still on this tab
      _checkAndStartTimer(_currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_error != null) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text(
          "Error loading coupons: $_error",
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_coupons.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: const Text(
          "No external coupons available",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: _coupons.length,
          options: CarouselOptions(
            height: 200,
            viewportFraction: 0.9,
            enlargeCenterPage: true,
            autoPlay: false,
            enableInfiniteScroll: false,
            onPageChanged: _onPageChanged,
          ),
          itemBuilder: (context, index, realIndex) {
            return _buildCouponItem(_coupons[index], index);
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _coupons.asMap().entries.map((entry) {
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 4.0,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (const Color(
                  0xFF6B5AE0,
                )).withOpacity(_currentIndex == entry.key ? 0.9 : 0.4),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCouponItem(ExternalCoupon coupon, int index) {
    final bool isCurrent = _currentIndex == index;
    final bool showVideo = isCurrent && _isVideoInitialized;

    // Check specifically for initialized controller
    final bool videoReady = _isYoutubeVideo
        ? (_youtubeController != null)
        : (_videoController != null && _videoController!.value.isInitialized);

    return GestureDetector(
      onTap: () => _openCouponDetails(coupon),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            CachedNetworkImage(
              imageUrl: coupon.imgUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image, color: Colors.grey),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Center(child: Icon(Icons.error)),
              ),
            ),

            // Video Layer
            if (showVideo && videoReady)
              _isYoutubeVideo
                  ? IgnorePointer(
                      // Ignore interaction on the small video
                      ignoring: true,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          // Arbitrary large size to fill/cover the container
                          // as YouTube player doesn't behave like a texture exactly
                          width: 480,
                          height: 270,
                          child: YoutubePlayer(
                            key: ValueKey(
                              'yt_${coupon.id}_$index',
                            ), // UNIQUE KEY PER CARD
                            controller: _youtubeController!,
                            showVideoProgressIndicator: false,
                          ),
                        ),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),

            // Text Content
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    coupon.couponTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coupon.couponDescription,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Mute Button
            if (showVideo && videoReady)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _toggleMute,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Icon(
                      _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

            // Exclusive Badge
            if (coupon.isExclusive)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'EXCLUSIVE',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: CarouselSlider(
        options: CarouselOptions(
          height: 200,
          viewportFraction: 0.9,
          enlargeCenterPage: true,
        ),
        items: [1, 2, 3].map((i) {
          return Builder(
            builder: (BuildContext context) {
              return Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

class ExternalCouponFullScreenPopup extends StatelessWidget {
  final ExternalCoupon coupon;

  const ExternalCouponFullScreenPopup({super.key, required this.coupon});

  Future<void> _launchURL() async {
    final Uri url = Uri.parse(coupon.externalUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Content
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  flex: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: coupon.imgUrl,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                              Colors.black,
                            ],
                            stops: const [0.4, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.black, // Continue background
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coupon.couponTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildInfoSection(
                          "Description",
                          coupon.couponDescription,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoSection(
                          "Benefits",
                          coupon.couponBenefits,
                          icon: Icons.card_giftcard,
                          color: Colors.amber,
                        ),

                        if (coupon.couponCode.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white30),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "CODE: ",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  coupon.couponCode,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const Spacer(),

                        if (coupon.couponTnc.isNotEmpty) ...[
                          Text(
                            "Terms & Conditions:",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            coupon.couponTnc,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 24),
                        ],

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _launchURL,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Visit Link",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Close button
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    String title,
    String content, {
    IconData? icon,
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(icon, color: color ?? Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color ?? Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
