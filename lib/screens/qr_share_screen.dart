import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uspeak/services/config_service.dart';
import 'package:flutter/services.dart'; // 用于剪贴板功能

class QrShareScreen extends StatefulWidget {
  const QrShareScreen({Key? key}) : super(key: key);

  @override
  State<QrShareScreen> createState() => _QrShareScreenState();
}

class _QrShareScreenState extends State<QrShareScreen> {
  late Future<String> _serverUrlFuture;
  late ConfigService _configService;

  @override
  void initState() {
    super.initState();
    _configService = ConfigService();
    _serverUrlFuture = _getServerUrl();
  }

  Future<String> _getServerUrl() async {
    final config = await _configService.getConfig();
    return config['api_server_url'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分享服务器地址'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: FutureBuilder<String>(
          future: _serverUrlFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
              return const Center(
                child: Text('无法获取服务器地址，请检查设置'),
              );
            }

            String serverUrl = snapshot.data!;
            
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '扫描二维码以快速设置服务器地址',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: QrImageView(
                      data: serverUrl,
                      version: QrVersions.auto,
                      size: 200.0,
                      gapless: false,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SelectableText(
                  serverUrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    // 复制URL到剪贴板
                    Clipboard.setData(ClipboardData(text: serverUrl)).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('服务器地址已复制到剪贴板')),
                      );
                    });
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('复制地址'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}