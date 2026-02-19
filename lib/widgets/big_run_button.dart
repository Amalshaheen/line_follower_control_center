import 'package:flutter/material.dart';

class BigRunButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onPressed;

  const BigRunButton({
    super.key,
    required this.isRunning,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isRunning ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: isRunning ? const Color(0xFFEF4444).withOpacity(0.5) : const Color(0xFF10B981).withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          isRunning ? "STOP BOT" : "START BOT",
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
