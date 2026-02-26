import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class ApiService {
  static String? _baseUrl;

  static Future<String> getBaseUrl() async {
    if (_baseUrl == null) {
      final configService = ConfigService();
      final config = await configService.getConfig();
      _baseUrl = config['api_server_url'];
    }
    return _baseUrl!;
  }

  /// 获取所有段落列表
  static Future<List<Map<String, dynamic>>> getPassageList() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/passageList'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('获取段落列表失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取段落列表时发生错误: $e');
    }
  }

  /// 获取特定段落内容
  static Future<Map<String, dynamic>> getPassage(int passageId) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/passageGet/$passageId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('获取段落失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取段落时发生错误: $e');
    }
  }

  /// 获取分句后的段落内容
  static Future<List<String>> getReadingSentence(int id) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/getReadingSentence/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<String>();
      } else {
        throw Exception('获取分句内容失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取分句内容时发生错误: $e');
    }
  }

  /// 提交音频文件进行处理
  static Future<Map<String, dynamic>> submitAudio(
      int passageId, String filePath) async {
    try {
      final baseUrl = await getBaseUrl();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/submitAudio'),
      );
      
      request.fields['passage_id'] = passageId.toString();
      request.files.add(await http.MultipartFile.fromPath('audio', filePath));

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      } else {
        throw Exception('提交音频失败: ${response.statusCode}, $responseBody');
      }
    } catch (e) {
      throw Exception('提交音频时发生错误: $e');
    }
  }

  /// 获取处理结果
  static Future<Map<String, dynamic>> getResult(String accessToken) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/getResult/$accessToken'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 400) {
        throw Exception(json.decode(response.body)['error']);
      } else {
        throw Exception('获取结果失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取结果时发生错误: $e');
    }
  }

  /// 获取所有会话数据
  static Future<List<dynamic>> getAllSessions() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/getallsessions'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data;
        } else {
          throw Exception('无效的响应格式');
        }
      } else {
        throw Exception('获取会话数据失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取会话数据时发生错误: $e');
    }
  }
  
  /// 获取评分 - 新的API端点
  static Future<double> getScore(String og, String rec) async {
    try {
      final baseUrl = await getBaseUrl();
      // 对参数进行URL编码，处理可能包含特殊字符的情况
      String encodedOg = Uri.encodeComponent(og);
      String encodedRec = Uri.encodeComponent(rec);
      final response = await http.get(
        Uri.parse('$baseUrl/getScore/$encodedOg/$encodedRec'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['score'] as num?)?.toDouble() ?? 0.0;
      } else {
        throw Exception('获取评分失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取评分时发生错误: $e');
    }
  }
}