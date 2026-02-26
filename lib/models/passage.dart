import '../services/api_service.dart';
import 'package:logging/logging.dart'; // 导入logging包

class Passage {
  final int id;
  final String title;
  final String content;

  const Passage({
    required this.id,
    required this.title,
    required this.content,
  });

  static Future<List<Passage>> getPassagesFromApi() async {
    try {
      final apiPassages = await ApiService.getPassageList();
      return apiPassages.asMap().entries.map((entry) {
        final passage = entry.value;
        return Passage(
          id: passage['id'] ?? entry.key,
          title: passage['title'] ?? 'Untitled',
          content: passage['content'] ?? '',
        );
      }).toList();
    } catch (e) {
      // 如果API获取失败，抛出错误而不是使用本地数据
      throw Exception('获取API段落失败: $e');
    }
  }
}