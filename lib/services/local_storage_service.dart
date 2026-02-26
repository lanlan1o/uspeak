import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalStorageService {
  static const String _historyKey = 'practice_history';

  // 添加一条练习记录
  static Future<void> addPracticeRecord(Map<String, dynamic> record) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 获取现有记录
    List<String>? existingRecords = prefs.getStringList(_historyKey);
    if (existingRecords == null) {
      existingRecords = [];
    }

    // 添加新记录
    record['timestamp'] = DateTime.now().toIso8601String();
    existingRecords.insert(0, jsonEncode(record)); // 插入到开头，最新的记录在前面

    // 限制记录数量，最多保存20条
    if (existingRecords.length > 20) {
      existingRecords = existingRecords.sublist(0, 20);
    }

    await prefs.setStringList(_historyKey, existingRecords);
  }

  // 获取所有练习记录
  static Future<List<Map<String, dynamic>>> getPracticeRecords() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? recordsJson = prefs.getStringList(_historyKey);
    
    if (recordsJson == null) {
      return [];
    }

    List<Map<String, dynamic>> records = [];
    for (String recordJson in recordsJson) {
      try {
        Map<String, dynamic> record = jsonDecode(recordJson);
        records.add(record);
      } catch (e) {
        // 如果解析失败，跳过这条记录
        continue;
      }
    }

    return records;
  }

  // 清除所有记录
  static Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}