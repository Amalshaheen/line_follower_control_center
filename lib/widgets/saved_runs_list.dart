import 'package:flutter/material.dart';
import '../models/run_data.dart';

class SavedRunsList extends StatelessWidget {
  final List<RunData> runs;
  final Function(RunData) onRunSelected;
  final Function(String) onRunDeleted;
  final bool isLoading;

  const SavedRunsList({
    super.key,
    required this.runs,
    required this.onRunSelected,
    required this.onRunDeleted,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
        ),
      );
    }

    if (runs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: const Color(0xFF2D3748),
            ),
            const SizedBox(height: 16),
            const Text(
              "No saved runs yet",
              style: TextStyle(
                color: Color(0xFF2D3748),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: runs.length,
      itemBuilder: (context, index) {
        final run = runs[runs.length - 1 - index]; // Show newest first
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Card(
            color: const Color(0xFF1F2937),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(
                color: Color(0xFF2D3748),
                width: 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              title: Text(
                "Run #${run.id}",
                style: const TextStyle(
                  color: Color(0xFF06B6D4),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    "Time: ${run.formattedTime} | Speed: ${run.baseSpeed}",
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    "PID: Kp=${run.kp.toStringAsFixed(1)} Ki=${run.ki.toStringAsFixed(1)} Kd=${run.kd.toStringAsFixed(1)}",
                    style: const TextStyle(
                      color: Color(0xFFA0AEC0),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    run.formattedDate,
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
                onPressed: () {
                  onRunDeleted(run.id);
                },
              ),
              onTap: () {
                onRunSelected(run);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Loaded configuration from Run #${run.id}',
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
