import 'package:flutter/material.dart';
import '../core/constants.dart';

class HomeCardButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const HomeCardButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<HomeCardButton> createState() => _HomeCardButtonState();
}

class _HomeCardButtonState extends State<HomeCardButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: widget.onTap,
      onHighlightChanged: (value) {
        setState(() => _isPressed = value);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 30, color: Colors.white70),
              const SizedBox(height: 8),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
