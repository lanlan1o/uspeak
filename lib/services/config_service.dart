import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _keyLanguage = 'current_language';
  static const String _keyApiServerUrl = 'api_server_url';
  static const String _keyPollTimeoutSeconds = 'poll_timeout_seconds';  // 添加轮询超时时间配置

  Future<Map<String, dynamic>> getConfig() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'current_language': prefs.getString(_keyLanguage) ?? 'en-US',
      'api_server_url': prefs.getString(_keyApiServerUrl) ?? 'http://localhost:5000',
      'poll_timeout_seconds': prefs.getInt(_keyPollTimeoutSeconds) ?? 30,  // 添加默认超时时间
    };
  }

  Future<void> saveConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_keyLanguage, config['current_language']);
    await prefs.setString(_keyApiServerUrl, config['api_server_url'] ?? 'http://localhost:5000');
    await prefs.setInt(_keyPollTimeoutSeconds, config['poll_timeout_seconds'] ?? 30);  // 保存超时时间
  }
}