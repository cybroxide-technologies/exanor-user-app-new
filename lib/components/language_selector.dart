import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async'; // Added for Timer
import 'package:exanor/services/translation_service.dart';
import 'package:exanor/components/translation_diagnostics.dart';
import 'package:exanor/components/translation_test_widget.dart';

class LanguageSelector extends StatefulWidget {
  final Function(SupportedLanguage)? onLanguageSelected;
  final bool showOnlyIndianLanguages;
  final String searchHint;
  final bool navigateToSplashOnSelection;

  const LanguageSelector({
    super.key,
    this.onLanguageSelected,
    this.showOnlyIndianLanguages = false,
    this.searchHint = 'Search languages...',
    this.navigateToSplashOnSelection = false,
  });

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final TextEditingController _searchController = TextEditingController();
  List<SupportedLanguage> _filteredLanguages = [];
  final TranslationService _translationService = TranslationService.instance;
  Map<String, bool> _downloadedLanguages = {};
  Map<String, double> _downloadProgress = {};
  bool _showHelperTools = false;

  // Simulated progress timer
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));

    _initializeLanguages();

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _searchController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _initializeLanguages() {
    final languages = widget.showOnlyIndianLanguages
        ? _translationService.indianLanguages
        : _translationService.availableLanguages;

    setState(() {
      _filteredLanguages = languages;
    });

    _checkDownloadedLanguages();
  }

  Future<void> _checkDownloadedLanguages() async {
    final Map<String, bool> downloadedStatus = {};

    for (final language in _filteredLanguages) {
      try {
        final isDownloaded = await _translationService
            .isLanguageModelDownloaded(language.code);
        downloadedStatus[language.code] = isDownloaded;
      } catch (e) {
        // If check fails, assume not downloaded
        downloadedStatus[language.code] = false;
      }
    }

    if (mounted) {
      setState(() {
        _downloadedLanguages = downloadedStatus;
      });
    }
  }

  /// Force refresh downloaded languages status
  Future<void> _refreshDownloadedStatus() async {
    await _checkDownloadedLanguages();
  }

  void _filterLanguages(String query) {
    final languages = widget.showOnlyIndianLanguages
        ? _translationService.indianLanguages
        : _translationService.availableLanguages;

    setState(() {
      if (query.isEmpty) {
        _filteredLanguages = languages;
      } else {
        _filteredLanguages = languages
            .where(
              (language) =>
                  language.name.toLowerCase().contains(query.toLowerCase()) ||
                  language.nativeName.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  language.code.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  Future<void> _downloadLanguageModel(SupportedLanguage language) async {
    try {
      setState(() {
        _downloadedLanguages[language.code] = false;
        _downloadProgress[language.code] = 0.05; // Start with small progress
      });

      // Start simulated progress
      _progressTimer?.cancel();
      _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (
        timer,
      ) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          final current = _downloadProgress[language.code] ?? 0.0;
          if (current < 0.9) {
            _downloadProgress[language.code] =
                current +
                0.05 +
                (0.02 * (0.5 - current).abs()); // Random-ish curve
          } else {
            timer.cancel();
          }
        });
      });

      // Show user immediate feedback that it has started
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading ${language.name} model... Please wait.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Start actual download
      final success = await _translationService.downloadLanguageModel(
        language.code,
      );

      if (mounted) {
        // Now update final state atomically
        setState(() {
          _downloadedLanguages[language.code] = success;
          _downloadProgress.remove(language.code);
        });

        // Force refresh downloaded status to ensure consistency
        await _refreshDownloadedStatus();

        if (success) {
          // Show success message and update UI to show select button
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '✨ ${language.name} downloaded successfully! You can now select it.',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download ${language.name} model'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadedLanguages[language.code] = false;
          _downloadProgress.remove(language.code);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading ${language.name}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _selectLanguage(SupportedLanguage language) async {
    HapticFeedback.mediumImpact();

    final isDownloaded = _downloadedLanguages[language.code] ?? false;
    if (!isDownloaded && language.code != 'en') {
      final shouldDownload = await _showDownloadDialog(language);
      if (shouldDownload) {
        await _downloadLanguageModel(language);
      }
      return;
    }

    try {
      // Add timeout to prevent hanging
      final success = await Future.any([
        _translationService.changeLanguage(language.code),
        Future.delayed(const Duration(seconds: 10), () => false),
      ]);

      if (success && mounted) {
        widget.onLanguageSelected?.call(language);

        // Always navigate to splash screen after language selection
        Navigator.of(context).pop(); // Dismiss bottom sheet first
        await Future.delayed(const Duration(milliseconds: 100)); // Small delay
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/restart_app');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change language to ${language.name}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing language: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<bool> _showDownloadDialog(SupportedLanguage language) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Download ${language.name}?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'To use ${language.name}, we need to download a small language pack. This will only happen once.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white60
                                  : Colors.black54,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: theme.colorScheme.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Download',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeAnimation,
        _slideAnimation,
        _scaleAnimation,
      ]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                height: screenSize.height * 0.75, // Reduced height
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDarkMode
                              ? [
                                  Colors.grey[900]!.withOpacity(0.95),
                                  Colors.grey[800]!.withOpacity(0.9),
                                ]
                              : [
                                  Colors.white.withOpacity(0.95),
                                  Colors.grey[50]!.withOpacity(0.9),
                                ],
                        ),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildHeader(theme, isDarkMode),
                          _buildSearchSection(theme, isDarkMode),
                          // Helper tools removed for cleaner UI as per "artistic" request or moved
                          if (_showHelperTools)
                            _buildHelperTools(theme, isDarkMode),
                          Expanded(
                            child: _buildLanguageList(theme, isDarkMode),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.showOnlyIndianLanguages
                          ? 'Indian Languages'
                          : 'Choose Language',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Translate your entire app experience',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildHeaderButton(
                icon: Icons.close_rounded,
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
                theme: theme,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            child: Icon(
              icon,
              color: isDarkMode ? Colors.white : Colors.black87,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.withOpacity(
                            0.05,
                          ), // Very transparent background
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03), // Subtle border
                    ),
                    // Removed heavy shadow
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterLanguages,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      hintStyle: TextStyle(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.4)
                            : const Color(0xFF1F4C6B).withOpacity(0.5),
                        fontSize: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.6)
                            : const Color(0xFF1F4C6B).withOpacity(0.6),
                        size: 24,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _filterLanguages('');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.black.withOpacity(0.5),
                                size: 20,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildHeaderButton(
            icon: _showHelperTools
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            onPressed: () {
              setState(() {
                _showHelperTools = !_showHelperTools;
              });
              HapticFeedback.lightImpact();
            },
            tooltip: _showHelperTools ? 'Hide Tools' : 'Show Helper Tools',
            theme: theme,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildHelperTools(ThemeData theme, bool isDarkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Translation Tools',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.9)
                  : Colors.black.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Commented out as requested by user
              // _buildToolChip(
              //   icon: Icons.integration_instructions,
              //   label: 'Basic Guide',
              //   color: Colors.purple,
              //   onTap: () {
              //     Navigator.of(context).pop();
              //     showTranslationIntegrationGuide(context);
              //   },
              // ),
              // _buildToolChip(
              //   icon: Icons.translate,
              //   label: 'Universal Guide',
              //   color: Colors.orange,
              //   onTap: () {
              //     Navigator.of(context).pop();
              //     showUniversalTranslationGuide(context);
              //   },
              // ),
              // _buildToolChip(
              //   icon: Icons.view_list,
              //   label: 'Live Example',
              //   color: Colors.teal,
              //   onTap: () {
              //     Navigator.of(context).pop();
              //     showComprehensiveTranslationExample(context);
              //   },
              // ),
              _buildToolChip(
                icon: Icons.play_arrow,
                label: 'Test Download',
                color: Colors.green,
                onTap: () {
                  Navigator.of(context).pop();
                  showTranslationTest(context);
                },
              ),
              _buildToolChip(
                icon: Icons.help_outline,
                label: 'Diagnostics',
                color: theme.colorScheme.primary,
                onTap: () {
                  Navigator.of(context).pop();
                  showTranslationDiagnostics(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageList(ThemeData theme, bool isDarkMode) {
    if (_filteredLanguages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No languages found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : Colors.black.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: _filteredLanguages.length,
      itemBuilder: (context, index) {
        final language = _filteredLanguages[index];
        final isDownloaded =
            _downloadedLanguages[language.code] ??
            (language.code == 'en'); // English is always available
        final downloadProgress = _downloadProgress[language.code];
        final isCurrentLanguage =
            language.code == _translationService.currentLanguageCode;

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 200 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _buildLanguageCard(
                  language: language,
                  isDownloaded: isDownloaded,
                  downloadProgress: downloadProgress,
                  isCurrentLanguage: isCurrentLanguage,
                  theme: theme,
                  isDarkMode: isDarkMode,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageCard({
    required SupportedLanguage language,
    required bool isDownloaded,
    required double? downloadProgress,
    required bool isCurrentLanguage,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentLanguage
            ? theme.colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentLanguage
              ? theme.colorScheme.primary.withOpacity(0.5)
              : isDarkMode
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectLanguage(language),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Flag
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: language.imageUrl != null
                        ? Image.network(
                            language.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildTextFlag(language),
                          )
                        : _buildTextFlag(language),
                  ),
                ),
                const SizedBox(width: 16),

                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        language.nativeName,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.5)
                              : Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Button
                if (downloadProgress != null)
                  _buildProgressIndicator(downloadProgress, theme)
                else if (isCurrentLanguage)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  )
                else if (isDownloaded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Select',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                    ),
                    child: Icon(
                      Icons.download_rounded,
                      size: 20,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFlag(SupportedLanguage language) {
    return Container(
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Text(language.flag, style: const TextStyle(fontSize: 24)),
    );
  }

  Widget _buildProgressIndicator(double progress, ThemeData theme) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced Language Button with glassmorphism and animated gradient boundary
class EnhancedLanguageButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final EdgeInsets? margin;

  const EnhancedLanguageButton({super.key, this.onPressed, this.margin});

  @override
  State<EnhancedLanguageButton> createState() => _EnhancedLanguageButtonState();
}

class _EnhancedLanguageButtonState extends State<EnhancedLanguageButton>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _gradientAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final translationService = TranslationService.instance;
    final currentLanguage = translationService.currentLanguage;

    return Container(
      margin: widget.margin ?? const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: Listenable.merge([_gradientAnimation, _pulseAnimation]),
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDarkMode
                          ? [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ]
                          : [
                              Colors.white.withOpacity(0.8),
                              Colors.white.withOpacity(0.4),
                            ],
                    ),
                    border: Border.all(width: 2, color: Colors.transparent),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [
                          _gradientAnimation.value * 0.3,
                          _gradientAnimation.value * 0.7,
                          _gradientAnimation.value,
                        ],
                        colors: [
                          const Color(
                            0xFF3B82F6,
                          ).withOpacity(0.3 * _pulseAnimation.value), // Blue
                          const Color(
                            0xFF8B5CF6,
                          ).withOpacity(0.4 * _pulseAnimation.value), // Purple
                          const Color(
                            0xFF3B82F6,
                          ).withOpacity(0.2 * _pulseAnimation.value), // Blue
                        ],
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onPressed,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Language image and flag
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.05),
                                ),
                                child: ClipOval(
                                  child: currentLanguage.imageUrl != null
                                      ? Image.network(
                                          currentLanguage.imageUrl!,
                                          width: 32,
                                          height: 32,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Center(
                                                    child: Text(
                                                      currentLanguage.flag,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  ),
                                        )
                                      : Center(
                                          child: Text(
                                            currentLanguage.flag,
                                            style: const TextStyle(
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Language name in native language
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentLanguage.nativeName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 14,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      currentLanguage.name,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.7)
                                                : Colors.black.withOpacity(0.6),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Dropdown arrow
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.05),
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.8)
                                      : Colors.black.withOpacity(0.7),
                                ),
                              ),

                              // Active indicator if not English
                              if (currentLanguage.code != 'en')
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF3B82F6),
                                        const Color(0xFF8B5CF6),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withOpacity(0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Utility function to show language selector bottom sheet
Future<void> showLanguageSelector(
  BuildContext context, {
  Function(SupportedLanguage)? onLanguageSelected,
  bool showOnlyIndianLanguages = false,
  bool navigateToSplashOnSelection = false,
}) async {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LanguageSelector(
      onLanguageSelected: onLanguageSelected,
      showOnlyIndianLanguages: showOnlyIndianLanguages,
      navigateToSplashOnSelection: navigateToSplashOnSelection,
    ),
  );
}
