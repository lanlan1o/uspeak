import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uspeak/services/config_service.dart'; // 导入ConfigService

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({Key? key}) : super(key: key);

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  MobileScannerController cameraController = MobileScannerController();
  late ConfigService _configService; // 声明ConfigService实例

  @override
  void initState() {
    super.initState();
    _configService = ConfigService(); // 初始化ConfigService
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      // 如果没有相机权限，显示提示
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要相机权限'),
            content: const Text('请在设置中开启相机权限以使用二维码扫描功能'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描二维码'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off);
                  case TorchState.on:
                    return const Icon(Icons.flash_on);
                  default:
                    return const Icon(Icons.flashlight_off_sharp);
                }
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          final String? barcode = capture.barcodes.first.rawValue;
          
          if (barcode != null) {
            // 解析二维码内容，如果是URL则提示用户
            if (Uri.tryParse(barcode)?.hasScheme ?? false) {
              _handleScannedUrl(barcode);
            } else {
              // 如果不是有效的URL，提示用户
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('扫描结果'),
                    content: Text('扫描到的内容不是有效的URL:\n$barcode'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('确定'),
                      )
                    ],
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  Future<void> _handleScannedUrl(String url) async {
    if (!mounted) return;

    // 验证URL格式
    Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('错误'),
          content: Text('扫描到的URL格式无效: $url'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            )
          ],
        ),
      );
      return;
    }

    // 确认是否要设置为服务器地址
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
              Navigator.of(context).pop(); // 关闭确认对话框
              
              try {
                // 保存服务器地址到配置服务
                final config = await _configService.getConfig();
                await _configService.saveConfig({
                  'current_language': config['current_language'],
                  'api_server_url': url,
                  'poll_timeout_seconds': config['poll_timeout_seconds'] ?? 30,
                });
                
                // 通知用户设置成功
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('设置成功'),
                      content: Text('服务器地址已更新为:\n$url'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // 关闭成功对话框
                            Navigator.of(context).pop(url); // 返回扫描到的URL
                          },
                          child: const Text('确定'),
                        )
                      ],
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('错误'),
                      content: Text('保存服务器地址失败: $e'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('确定'),
                        )
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}