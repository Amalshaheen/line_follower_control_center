import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/run_data.dart';

class RunDataService {
  static const String runDataFileName = 'runs_data.json';

  Future<File> _getRunDataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$runDataFileName');
  }

  Future<void> saveRun(RunData run) async {
    try {
      final file = await _getRunDataFile();
      List<RunData> runs = await getAllRuns();
      runs.add(run);
      
      final jsonList = runs.map((r) => r.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving run: $e');
    }
  }

  Future<List<RunData>> getAllRuns() async {
    try {
      final file = await _getRunDataFile();
      
      if (!await file.exists()) {
        return [];
      }
      
      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }
      
      final jsonList = jsonDecode(contents) as List;
      return jsonList.map((json) => RunData.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error reading runs: $e');
      return [];
    }
  }

  Future<void> deleteRun(String id) async {
    try {
      final file = await _getRunDataFile();
      List<RunData> runs = await getAllRuns();
      runs.removeWhere((run) => run.id == id);
      
      final jsonList = runs.map((r) => r.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error deleting run: $e');
    }
  }

  Future<void> clearAllRuns() async {
    try {
      final file = await _getRunDataFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing runs: $e');
    }
  }
}
