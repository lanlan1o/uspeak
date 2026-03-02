import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 用于检测平台类型
import 'dart:io' show Platform; // 用于检测操作系统平台
import 'package:uspeak/models/passage.dart';
import 'package:uspeak/services/config_service.dart';
import 'package:uspeak/widgets/passages_list.dart';
import 'package:uspeak/widgets/history_list.dart';
import 'package:uspeak/screens/practice_screen.dart';
import 'package:uspeak/screens/qr_scan_screen.dart'; // 导入二维码扫描屏幕
import 'package:uspeak/screens/qr_share_screen.dart'; // 导入二维码分享屏幕
import 'package:uspeak/services/api_service.dart';
import 'package:logging/logging.dart'; // 导入logging包

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final Logger _logger = Logger('HomeScreen'); // 创建logger实例
  
  late ConfigService _configService;
  List<Passage> _passages = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _configService = ConfigService();
    _loadPassages();
  }

  Future<void> _loadPassages() async {
    try {
      final passages = await Passage.getPassagesFromApi();
      if (mounted) {
        setState(() {
          _passages = passages;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      _logger.severe('加载段落失败: $e');
      if (mounted) {
        setState(() {
          _passages = []; 
          _isLoading = false;
          _errorMessage = '无法从服务器加载文章: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('英语朗读练习系统'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPassages, // 添加刷新功能
          ),
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QrShareScreen()),
              );
            },
          ),
          if (!kIsWeb && !Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)  // 仅在移动平台上显示扫描按钮
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QrScanScreen()),
                );
                
                if (result != null && result is String) {
                  // 如果扫描到了URL，询问用户是否要设置为服务器地址
                  await _confirmSetServerAddress(result);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await _showSettingsDialog(context);
              // 设置对话框关闭后自动重载数据
              if(mounted) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
              }
              _loadPassages();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPassages,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 当前设置显示区域
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _configService.getConfig(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final config = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'API服务器: ${config['api_server_url']}',
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '轮询超时: ${config['poll_timeout_seconds']}秒',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        );
                      } else {
                        return const Text('加载设置中...', style: TextStyle(fontSize: 14));
                      }
                    },
                  ),
                ),
                
                // 可练习文章标签
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    '可练习文章',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                
                // 文章列表
                Expanded(
                  flex: 2,
                  child: PassagesList(
                    passages: _passages,
                    onTap: (int index) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PracticeScreen(
                            passageIndex: index,
                            passage: _passages[index],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // 历史记录标签
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    '历史记录',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                
                // 历史记录列表
                Expanded(
                  flex: 1,
                  child: HistoryList(),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmSetServerAddress(String url) async {
    final config = await _configService.getConfig();
    bool isValidUrl = Uri.tryParse(url)?.hasScheme ?? false;
    
    if (!isValidUrl) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('无效的URL'),
            content: Text('扫描到的URL格式无效: $url'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              )
            ],
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认设置服务器'),
          content: Text('是否将以下URL设置为服务器地址？\n\n$url'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // 关闭对话框
                
                // 保存新的服务器地址
                await _configService.saveConfig({
                  'current_language': config['current_language'],
                  'api_server_url': url,
                  'poll_timeout_seconds': config['poll_timeout_seconds'] ?? 30,
                });
                
                // 重置API服务的基础URL，以便使用新的服务器地址
                ApiService.getBaseUrl();
                
                // 重新加载段落
                if (mounted) {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                }
                
                _loadPassages();
              },
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final config = await _configService.getConfig();

    String apiServerUrl = config['api_server_url'];
    int pollTimeoutSeconds = config['poll_timeout_seconds'] ?? 30;

    TextEditingController apiServerUrlController = TextEditingController(text: apiServerUrl);
    TextEditingController pollTimeoutController = TextEditingController(text: pollTimeoutSeconds.toString());

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('应用设置'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextField(
                      controller: apiServerUrlController,
                      decoration: const InputDecoration(
                        labelText: 'API服务器地址',
                        hintText: '例如: http://localhost:5000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pollTimeoutController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '轮询超时时间(秒)',
                        hintText: '例如: 30',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('取消'),
                  onPressed: () {
                    Navigator.of(context).pop(); // 关闭对话框
                  },
                ),
                TextButton(
                  child: const Text('保存'),
                  onPressed: () async {
                    int timeoutValue = 30;
                    try {
                      timeoutValue = int.parse(pollTimeoutController.text);
                      if (timeoutValue < 5) {
                        timeoutValue = 5; // 最小值为5秒
                      } else if (timeoutValue > 300) {
                        timeoutValue = 300; // 最大值为300秒
                      }
                    } catch (e) {
                      // 如果解析失败，使用默认值
                      timeoutValue = 30;
                    }
                    
                    await _configService.saveConfig({
                      'current_language': config['current_language'],
                      'api_server_url': apiServerUrlController.text,
                      'poll_timeout_seconds': timeoutValue,
                    });
                    
                    // 重置API服务的基础URL，以便使用新的服务器地址
                    ApiService.getBaseUrl();
                    
                    if (mounted) {
                      Navigator.of(context).pop(); // 关闭对话框
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}