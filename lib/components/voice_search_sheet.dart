import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:exanor/components/translation_widget.dart';

class VoiceSearchSheet extends StatefulWidget {
  const VoiceSearchSheet({super.key});

  @override
  State<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends State<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Say something...';
  String _sampleQuery = "masala dosa";
  double _confidence = 1.0;
  bool _initError = false;

  late AnimationController _animationController;

  final List<String> _sampleQueries = [
    "masala dosa",
    "pizza",
    "burger",
    "biryani",
    "cake",
    "coffee",
  ];

  @override
  void initState() {
    super.initState();
    _sampleQuery = _sampleQueries[Random().nextInt(_sampleQueries.length)];
    _speech = stt.SpeechToText();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Delay slightly to allow UI to build before asking permission/listening
    Future.delayed(const Duration(milliseconds: 500), _startListening);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speech.stop();
    super.dispose();
  }

  Timer? _silenceTimer;
  bool _speechDetected = false;

  Future<void> _startListening() async {
    // Check permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        setState(() {
          _text = "Microphone permission is required.";
          _initError = true;
        });
        return;
      }
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        print('STT Sheet Status: $status');
        if (mounted) {
          if (status == 'listening') {
            setState(() => _isListening = true);
            _animationController.repeat();
          } else if (status == 'notListening' || status == 'done') {
            _silenceTimer?.cancel();
            setState(() {
              _isListening = false;
              if (!_speechDetected &&
                  (_text == 'Listening...' || _text == 'Say something...')) {
                _text = "No voice detected. Tap to retry.";
                _initError = true;
              }
            });
            _animationController.stop();
          }
        }
      },
      onError: (errorNotification) {
        print('STT Sheet Error: $errorNotification');
        _silenceTimer?.cancel();
        if (mounted) {
          setState(() {
            _isListening = false;
            // Only show error if we didn't detect speech or it wasn't a manual timeout
            if (!_speechDetected) {
              _text = "Didn't catch that. Tap to try again.";
              _initError = true;
            }
          });
          _animationController.stop();
        }
      },
    );

    if (available) {
      if (mounted) {
        setState(() {
          _isListening = true;
          _text = "Listening...";
          _initError = false;
          _speechDetected = false;
        });
        _animationController.repeat();
      }

      // Start manual silence timer immediately upon listening
      _silenceTimer?.cancel();
      _silenceTimer = Timer(const Duration(seconds: 5), () {
        if (!_speechDetected && _isListening) {
          print("Manual silence timeout - cancelling");
          _speech.cancel(); // Abort immediately
          if (mounted) {
            setState(() {
              _isListening = false;
              _text = "No voice detected. Tap to retry.";
              _initError = true;
            });
            _animationController.stop();
          }
        }
      });

      _speech.listen(
        onResult: (val) {
          if (val.recognizedWords.isNotEmpty) {
            _speechDetected = true;
            _silenceTimer?.cancel();
          }

          if (mounted) {
            setState(() {
              _text = val.recognizedWords;
              if (val.hasConfidenceRating && val.confidence > 0) {
                _confidence = val.confidence;
              }
            });

            if (val.finalResult && val.recognizedWords.isNotEmpty) {
              // Close and return result
              Future.delayed(const Duration(milliseconds: 500), () {
                Navigator.of(context).pop(val.recognizedWords);
              });
            }
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        listenMode: stt.ListenMode.search,
        cancelOnError: true,
        partialResults: true,
      );
    } else {
      if (mounted) {
        setState(() {
          _isListening = false;
          _text = "Speech recognition unavailable.";
          _initError = true;
        });
        _animationController.stop();
      }
    }
  }

  void _onMicTap() {
    _silenceTimer?.cancel();
    if (_isListening) {
      _speech.stop();
      // Provide immediate feedback for manual stop
      setState(() {
        _isListening = false;
        if (_text == 'Listening...' || _text == 'Say something...') {
          _text = "Tap to retry";
          _initError = true;
        }
      });
      _animationController.stop();
    } else {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Close button (X) at the bottom in the image, but usually top right is standard.
          // Image shows it floating above, but let's put it top right or bottom for UX.
          // Image actually has X in a circle floating above the sheet.
          // We'll put it top right for now inside the sheet as it's easier.
          // Or we can follow the exact design: X button seems separate.
          // Let's stick to simple layout first: Text -> Sample -> Mic -> Loading.
          TranslatedText(
            "Hi, I'm listening. Try saying...",
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 80,
            alignment: Alignment.center,
            child: Text(
              _isListening
                  ? (_text == 'Say something...'
                        ? '"$_sampleQuery"'
                        : '"$_text"')
                  : (_initError ? _text : 'Tap microphone to speak'),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Mic Button with Pulse Animation
          GestureDetector(
            onTap: _onMicTap,
            child: SizedBox(
              width: 150,
              height: 150,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Ripple
                      if (_isListening)
                        Container(
                          width: 100 + (_animationController.value * 40),
                          height: 100 + (_animationController.value * 40),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withOpacity(
                              0.3 * (1 - _animationController.value),
                            ),
                          ),
                        ),
                      // Inner Ripple
                      if (_isListening)
                        Container(
                          width: 80 + (_animationController.value * 20),
                          height: 80 + (_animationController.value * 20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withOpacity(
                              0.5 * (1 - _animationController.value),
                            ),
                          ),
                        ),
                      // Mic Button
                      Container(
                        height: 72,
                        width: 72,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _initError
                              ? Icons.refresh_rounded
                              : (_isListening
                                    ? Icons.mic
                                    : Icons.mic_none_rounded),
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
