import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 用于检测平台类型
import '../services/api_service.dart';
import '../services/local_storage_service.dart'; // 导入本地存储服务
import 'package:logging/logging.dart'; // 导入logging包

class HistoryList extends StatefulWidget {
  const HistoryList({super.key}); // 使用super参数

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  static final Logger _logger = Logger('HistoryList'); // 创建logger实例
  
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() async {
    try {
      List<Map<String, dynamic>> history = [];

      if (kIsWeb) {
        // Web平台：从服务器加载历史记录
        final sessions = await ApiService.getAllSessions();
        // 将会话数据转换为历史记录格式
        for (var session in sessions) {
          // 确保数据结构正确
          if (session.containsKey('passage_id') && session.containsKey('score')) {
            int passageId = session['passage_id'];
            double score = session['score']?.toDouble() ?? 0.0;
            String timestamp = session['timestamp'] ?? '';
            
            // 简化的日期格式处理
            String displayTime = timestamp.isNotEmpty ? timestamp.substring(11, 19) : '未知时间';
            
            history.add({
              'passage_name': '段落 $passageId',
              'avg_score': score,
              'timestamp': displayTime,
              'sentence_count': 1, // 暂时设为1，实际应用中可以计算句子数量
            });
          }
        }
      } else {
        // 非Web平台：从本地存储加载历史记录
        final localHistory = await LocalStorageService.getPracticeRecords();
        for (var record in localHistory) {
          double averageScore = record['average_score']?.toDouble() ?? 0.0;
          int sentenceCount = record['sentence_count'] ?? 0;
          String timestamp = record['timestamp'] ?? '';
          
          // 简化的日期格式处理
          String displayTime = timestamp.isNotEmpty ? timestamp.substring(11, 19) : '未知时间';
          
          history.add({
            'passage_name': '本地练习记录',
            'avg_score': averageScore,
            'timestamp': displayTime,
            'sentence_count': sentenceCount,
          });
        }
      }

      // 限制历史记录的数量，避免过多的数据占用内存
      history = history.take(20).toList(); // 限制最多只显示20条历史记录

      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.warning('加载历史记录失败: $e');
      
      // Web平台的备选数据
      List<Map<String, dynamic>> fallbackHistory = [];
      if (kIsWeb) {
        fallbackHistory = [
          {'passage_name': 'Sample Passage 1', 'avg_score': 85.5, 'timestamp': '10:30:15', 'sentence_count': 5},
          {'passage_name': 'Sample Passage 2', 'avg_score': 92.0, 'timestamp': '09:45:22', 'sentence_count': 8},
          {'passage_name': 'Sample Passage 3', 'avg_score': 78.3, 'timestamp': '08:20:05', 'sentence_count': 6},
        ];
      } else {
        // 非Web平台的备选数据
        try {
          final localHistory = await LocalStorageService.getPracticeRecords();
          for (var record in localHistory) {
            double averageScore = record['average_score']?.toDouble() ?? 0.0;
            int sentenceCount = record['sentence_count'] ?? 0;
            String timestamp = record['timestamp'] ?? '';
            
            // 简化的日期格式处理
            String displayTime = timestamp.isNotEmpty ? timestamp.substring(11, 19) : '未知时间';
            
            fallbackHistory.add({
              'passage_name': '本地练习记录',
              'avg_score': averageScore,
              'timestamp': displayTime,
              'sentence_count': sentenceCount,
            });
          }
        } catch (localError) {
          _logger.warning('加载本地历史记录失败: $localError');
        }
      }

      fallbackHistory = fallbackHistory.take(20).toList(); // 限制最多只显示20条历史记录

      if (mounted) {
        setState(() {
          _history = fallbackHistory;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text(
        '暂无历史记录',
        style: TextStyle(color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
    }

    return ListView.builder(
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final record = _history[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            title: Text(
              '[${record['timestamp']}] ${record['passage_name']}',
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1, // 限制行数
              overflow: TextOverflow.ellipsis, // 超出省略
            ),
            subtitle: Text(
              '平均评分: ${record['avg_score'].toStringAsFixed(1)}分 (${record['sentence_count']}句)',
              maxLines: 1, // 限制行数
              overflow: TextOverflow.ellipsis, // 超出省略
            ),
            trailing: Text(
              '${record['avg_score']}分',
              style: TextStyle(
                color: _getColorForScore(record['avg_score']),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getColorForScore(double score) {
    if (score >= 90) {
      return Colors.green;
    } else if (score >= 70) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}