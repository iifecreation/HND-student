// Large animated circular push-to-talk microphone button with pulsing ring.

import 'package:flutter/material.dart';

/// Prominent circular microphone button with an expanding pulse animation when listening.
class MicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onPressed;
  final double size;

  const MicButton({
    super.key,
    required this.isListening,
    required this.onPressed,
    this.size = 72.0,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isListening) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = widget.isListening;
    final activeColor = isListening ? Colors.red.shade600 : theme.colorScheme.primary;

    return Semantics(
      button: true,
      label: isListening ? 'Stop listening' : 'Start voice input',
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return SizedBox(
            width: widget.size * 1.4,
            height: widget.size * 1.4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isListening)
                  Container(
                    width: widget.size * _pulseAnimation.value,
                    height: widget.size * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor.withValues(alpha: 0.25),
                    ),
                  ),
                Material(
                  color: activeColor,
                  shape: const CircleBorder(),
                  elevation: isListening ? 6 : 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onPressed,
                    child: SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: Icon(
                        isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: widget.size * 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
