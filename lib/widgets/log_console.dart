import 'package:flutter/material.dart';

class LogConsole extends StatelessWidget {
  final List<String> logs;

  const LogConsole({
    super.key,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (_, index) => Text(
          logs[index],
          style: const TextStyle(color: Colors.greenAccent),
        ),
      ),
    );
  }
}
