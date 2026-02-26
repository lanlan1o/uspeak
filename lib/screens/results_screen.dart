import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 用于检测平台类型
import '../services/local_storage_service.dart'; // 导入本地存储服务

class ResultsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> results;

  const ResultsScreen({
    Key? key,
    required this.results,
  }) : super(key: key);

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    
    // 在非Web平台上保存练习记录到本地
    if (!kIsWeb) {
      _savePracticeRecord();
    }
  }

  // 保存练习记录到本地
  void _savePracticeRecord() async {
    if (widget.results.isNotEmpty) {
      // 计算平均分数
      double totalScore = 0;
      for (var result in widget.results) {
        totalScore += result['score'] ?? 0;
      }
      double averageScore = totalScore / widget.results.length;

      // 创建记录对象
      Map<String, dynamic> record = {
        'average_score': averageScore,
        'sentence_count': widget.results.length,
        'details': widget.results,
      };

      // 保存到本地存储
      await LocalStorageService.addPracticeRecord(record);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('练习结果')),
        body: const Center(
          child: Text('暂无练习结果'),
        ),
      );
    }

    // 计算平均分数
    double totalScore = 0;
    for (var result in widget.results) {
      totalScore += result['score'] ?? 0;
    }
    double averageScore = totalScore / widget.results.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习结果'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 总体评分
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '总体评分',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${averageScore.toStringAsFixed(1)} 分',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('共 ${widget.results.length} 句练习'),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            const Text(
              '详细结果',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            
            const SizedBox(height: 10),
            
            // 结果列表 - 限制显示数量，防止内存占用过大
            Expanded(
              child: ListView.separated(
                itemCount: widget.results.length > 100 ? 100 : widget.results.length, // 限制最大显示数量
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final result = widget.results[index];
                  final score = result['score'] ?? 0;
                  
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '第 ${index + 1} 句',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '原文: ${result['original'] ?? ''}',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2, // 限制显示行数
                            overflow: TextOverflow.ellipsis, // 超出省略
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '识别: ${result['recognized'] ?? ''}',
                            maxLines: 2, // 限制显示行数
                            overflow: TextOverflow.ellipsis, // 超出省略
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('得分: '),
                              Text(
                                '${score.toStringAsFixed(1)} 分',
                                style: TextStyle(
                                  color: score >= 80 
                                    ? Colors.green 
                                    : score >= 60 
                                      ? Colors.orange 
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}