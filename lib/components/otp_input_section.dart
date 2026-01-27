import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OTPInputSection extends StatefulWidget {
  final String otpCode;
  final ValueChanged<String> onChanged;

  const OTPInputSection({
    super.key,
    required this.otpCode,
    required this.onChanged,
  });

  @override
  State<OTPInputSection> createState() => _OTPInputSectionState();
}

class _OTPInputSectionState extends State<OTPInputSection> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.otpCode;
    _controller.addListener(() {
      final text = _controller.text;
      if (text != widget.otpCode) {
        widget.onChanged(text);
      }
    });
  }

  @override
  void didUpdateWidget(OTPInputSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.otpCode != _controller.text) {
      _controller.text = widget.otpCode;
      // Keep cursor at end
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Hidden TextField to capture input
        // Moved off-screen to prevent cursor artifacts ("blue dot")
        Positioned(
          left: -1000,
          child: SizedBox(
            width: 1,
            height: 1,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              // Ensure keyboard stays open
              autofocus: true,
              showCursor: false,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                counterText: '',
              ),
            ),
          ),
        ),

        // Visible OTP Boxes
        GestureDetector(
          onTap: () {
            // Focus the hidden field when boxes are tapped
            FocusScope.of(context).requestFocus(_focusNode);
            // Ensure system keyboard shows up
            SystemChannels.textInput.invokeMethod('TextInput.show');
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 360,
              ), // Constraint to prevent massive boxes on tablets
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int index = 0; index < 4; index++) ...[
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1.0, // Force strict 1:1 square ratio
                        child: _buildOTPBox(index, theme),
                      ),
                    ),
                    if (index < 3)
                      const SizedBox(width: 12), // Fixed equal gaps
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPBox(int index, ThemeData theme) {
    final digit = index < widget.otpCode.length ? widget.otpCode[index] : '';
    final isActive = index == widget.otpCode.length;
    final isFilled = index < widget.otpCode.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate font size based on the actual rendered size of the box
        final boxSize = constraints.maxWidth;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isFilled
                ? theme.colorScheme.primary.withOpacity(0.05)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive || isFilled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacity(0.2),
              width: isActive ? 2 : 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              digit,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: boxSize * 0.45, // Responsive font size
              ),
            ),
          ),
        );
      },
    );
  }
}
