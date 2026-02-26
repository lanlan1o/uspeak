import 'package:flutter/material.dart';
import 'package:uspeak/models/passage.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'dart:async';
import '../screens/results_screen.dart'; // 导入ResultsScreen
import 'package:logging/logging.dart'; // 导入logging包
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart'; // 添加kIsWeb支持

class PracticeScreen extends StatefulWidget {
  final int passageIndex;
  final Passage passage;

  const PracticeScreen({
    super.key,
    required this.passageIndex,
    required this.passage,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  static final Logger _logger = Logger('PracticeScreen');
  
  String _transcript = '';
  int _currentSentenceIndex = 0;
  List<String> _sentences = [];
  final List<double> _scores = [];
  final List<String> _recognizedResults = [];
  int _recordTime = 0;
  int _remainingTime = 0;
  Timer? _timer;
  bool _isRecording = false;
  bool _disposed = false;
  bool _isLoading = false;
  final AudioRecorder _recorder = AudioRecorder();
  String? _audioFilePath;
  bool _isProcessing = false; // 新增标志表示正在处理音频

  @override
  void initState() {
    super.initState();
    _loadSentences();
  }

  void _loadSentences() async {
    try {
      // 从API获取分句内容
      final sentences = await ApiService.getReadingSentence(widget.passageIndex);
      // 控制句子数量，避免过多句子导致内存占用过高
      final processedSentences = sentences.take(50).toList();
      
      if (!_disposed) {
        setState(() {
          _sentences = processedSentences;
          // 如果句子过长，进一步截断
          for (int i = 0; i < _sentences.length; i++) {
            if (_sentences[i].length > 500) { // 限制每个句子的最大长度
              _sentences[i] = _sentences[i].substring(0, 500);
            }
          }
        });
        
        // 计算录音时间
        _calculateRecordTime();
      }
    } catch (e) {
      _logger.warning('获取分句失败: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('错误'),
            content: const Text('无法从服务器获取分句内容，请检查网络连接和服务器设置'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // 返回上一页
                },
                child: const Text('确定'),
              )
            ],
          ),
        );
      }
    }
  }


  void _calculateRecordTime() {
    if (_currentSentenceIndex < _sentences.length) {
      String sentence = _sentences[_currentSentenceIndex];
      // 根据单词数量估算录音时间，参考Python代码的算法
      int wordCount = sentence.split(' ').length;
      _recordTime = (wordCount * 2 ~/ 5 + 5).clamp(5, 60); // 最少5秒，最多60秒
      _remainingTime = _recordTime;
    }
  }

  void _startRecordingWithTimer() async {
    // 如果在浏览器环境中，显示警告并阻止录音
    if (kIsWeb) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('浏览器环境限制'),
            content: const Text(
              '由于浏览器安全限制，当前版本无法在浏览器中录制音频。\n\n'
              '音频录制和评分功能需要在移动应用或桌面应用中使用。\n\n'
              '在浏览器中，您可以使用语音识别功能进行实时转录，但无法上传音频进行评分。'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              )
            ],
          ),
        );
      }
      // 浏览器环境中不执行任何操作，因为无法录音
      return;
    }
    
    _calculateRecordTime();
    _isRecording = true;
    
    // 开始录音
    try {
      // 获取临时目录来存储录音文件
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      _audioFilePath = '$tempPath/sentence_${DateTime.now().millisecondsSinceEpoch}.wav'; // 确保使用.wav扩展名
      
      // 检查录音权限
      if (await _recorder.hasPermission()) {
        var recorderConfig = RecordConfig(
          encoder: AudioEncoder.wav, // 使用WAV编码
        );
        
        await _recorder.start(
          recorderConfig,
          path: _audioFilePath!,
        );
      } else {
        _logger.severe('没有录音权限');
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有录音权限')),
          );
        }
        return;
      }
    } catch(e) {
      _logger.severe('录音启动失败: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音启动失败: $e')),
        );
      }
      return;
    }
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed || !_isRecording) {
        timer.cancel();
        return;
      }
      
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        _stopRecordingAndSubmit();
        timer.cancel();
      }
    });
  }

  void _stopRecordingAndSubmit() async {
    // 停止倒计时
    _timer?.cancel();
    
    // 停止录音
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    
    // 检查是否已获取到录音文件
    if (_audioFilePath == null) {
      _logger.warning('没有找到录音文件路径');
      if (mounted) {
        // 不自动提交，而是提示用户
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音文件未找到，无法自动提交，请手动提交')),
        );
        setState(() {
          _isRecording = false;
          _remainingTime = _recordTime;
        });
      }
      return;
    }
    
    setState(() {
      _isRecording = false;
      _isLoading = true; // 显示加载状态
      _isProcessing = true; // 设置处理标志
    });
    
    try {
      // 立即上传音频到服务器进行识别
      Map<String, dynamic> result = await ApiService.submitAudio(
        widget.passageIndex,
        _audioFilePath!,
      );
      
      String accessToken = result['access_token'];
      _logger.info('音频提交成功，访问令牌: $accessToken');
      
      // 轮询获取识别结果
      Map<String, dynamic> processingResult = await _pollForResult(accessToken);
      
      // 根据新的API响应格式处理结果
      String recognizedText = '';
      double score = 0.0;
      
      if (processingResult.containsKey('result')) {
        recognizedText = processingResult['result'];
      } else if (processingResult.containsKey('recognized_text')) {
        recognizedText = processingResult['recognized_text'];
      }
      
      if (processingResult.containsKey('score')) {
        score = processingResult['score'].toDouble();
      }
      
      // 如果服务器没有返回识别文本，给用户提示
      if (recognizedText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('未能识别出语音内容，请重试')),
          );
        }
        return;
      }
      
      // 保存识别结果
      if (_recognizedResults.length <= _currentSentenceIndex) {
        _recognizedResults.add(recognizedText);
      } else {
        _recognizedResults[_currentSentenceIndex] = recognizedText;
      }
      
      // 保存评分结果
      if (_scores.length <= _currentSentenceIndex) {
        _scores.add(score);
      } else {
        _scores[_currentSentenceIndex] = score;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音处理成功，得分: ${score.toStringAsFixed(1)}分')),
        );
      }
      
      // 更新界面显示识别结果和评分
      setState(() {
        _transcript = recognizedText;
        _isLoading = false;
        _isProcessing = false; // 重置处理标志
      });
    } catch (e) {
      _logger.severe('上传音频或获取结果失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('处理录音时出现错误: $e')),
        );
      }
    } finally {
      // 清理录音文件
      if (_audioFilePath != null) {
        try {
          File audioFile = File(_audioFilePath!);
          if (await audioFile.exists()) {
            await audioFile.delete();
          }
        } catch (e) {
          _logger.warning('删除录音文件失败: $e');
        }
        _audioFilePath = null;
      }

      if (!_disposed && mounted) {
        setState(() {
          _isLoading = false;
          _isProcessing = false; // 确保处理标志被重置
          // 确保录音结束后按钮回到开始状态
          _isRecording = false;
          _remainingTime = _recordTime;
        });
      }
    }
  }

  // 移除未使用的方法 _uploadAudioFile()
  
  Future<Map<String, dynamic>> _pollForResult(String accessToken) async {
    // 固定轮询超时时间为30秒，移除对配置服务的依赖
    int timeoutSeconds = 30; // 固定超时时间
    int pollInterval = 1; // 轮询间隔1秒
    int attempts = 0;
    int maxAttempts = timeoutSeconds ~/ pollInterval;

    while (attempts < maxAttempts) {
      try {
        Map<String, dynamic> result = await ApiService.getResult(accessToken);
        
        // 检查结果是否已完成处理
        if (result.containsKey('status') && result['status'] == 'completed') {
          return result;
        } else if (result.containsKey('recognized_text') && result['recognized_text'] != null) {
          // 如果已经有识别文本，认为处理已完成
          return result;
        } else if (result.containsKey('result')) {
          // 根据新返回格式，直接返回包含评分和识别文本的结果
          return result;
        }
      } catch (e) {
        _logger.warning('轮询过程中获取结果失败: $e');
      }

      // 等待轮询间隔
      await Future.delayed(Duration(seconds: pollInterval));
      attempts++;
      
      // 更新UI显示剩余尝试次数或剩余时间
      if (mounted) {
        int remainingAttempts = maxAttempts - attempts;
        int remainingSeconds = remainingAttempts * pollInterval;
        if (remainingSeconds <= 10 && remainingSeconds % 2 == 0) { // 每两秒显示一次剩余时间（最后10秒）
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('仍在处理中，剩余时间约: $remainingSeconds 秒')),
          );
        }
      }
    }

    throw Exception('服务器处理超时，请稍后重试');
  }

  void _nextSentence() {
    if (_currentSentenceIndex < _sentences.length - 1) {
      setState(() {
        _currentSentenceIndex++;
        _transcript = '';
        _calculateRecordTime(); // 重新计算时间
      });
    }
  }

  void _previousSentence() {
    if (_currentSentenceIndex > 0) {
      setState(() {
        _currentSentenceIndex--;
        _transcript = '';
        _calculateRecordTime(); // 重新计算时间
      });
    }
  }

  void _submitResults() async {
    // 显示加载状态
    if (!_disposed) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // 构建结果数据
      List<Map<String, dynamic>> results = [];
      for (int i = 0; i < _sentences.length && i < _recognizedResults.length; i++) {
        results.add({
          'original': _sentences[i],
          'recognized': _recognizedResults[i],
          'score': _scores.length > i ? _scores[i] : 0.0,
        });
      }

      // 导航到结果页面
      if (!mounted) return; // 检查widget是否仍然挂载
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(results: results),
        ),
      );
    } finally {
      if (!_disposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true; // 设置disposed标志
    _timer?.cancel(); // 取消定时器
    
    // 清理资源
    _sentences.clear();
    _scores.clear();
    _recognizedResults.clear();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sentences.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('练习模式')),
        body: const Center(child: Text('正在加载内容...')),
      );
    }

    return PopScope(  // 替换 WillPopScope
      canPop: false, // 禁用默认返回行为
      onPopInvokedWithResult: (bool didRequestPop, Object? result) async {  // 使用新的回调方法
        _stopRecordingAndSubmit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('分句练习'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // 在返回之前尝试停止录音
              _stopRecordingAndSubmit();
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            // 如果是Web平台，显示提示信息
            if (kIsWeb)
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.orange),
                onPressed: () {
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('浏览器提示'),
                        content: const Text(
                          '您正在浏览器中使用本应用。\n\n'
                          '请注意：\n'
                          '• 使用Chrome或Edge浏览器获得最佳体验\n'
                          '• 确保已允许网站使用麦克风\n'
                          '• 部分功能可能与原生应用略有不同'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('确定'),
                          )
                        ],
                      ),
                    );
                  }
                },
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 进度条
                    Text(
                      '第${_currentSentenceIndex + 1}句 共${_sentences.length}句',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 当前句子显示
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _sentences[_currentSentenceIndex],
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 识别结果显示
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '识别结果:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _transcript.isEmpty ? '等待录音...' : _transcript,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // 录音时间和倒计时
                    Row(
                      children: [
                        const Text('录音时长:', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text('$_recordTime 秒', 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('剩余: $_remainingTime 秒',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _remainingTime < 5 ? Colors.red : Colors.black,
                            )),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 录音按钮
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _isRecording || _isLoading
                            ? null  // 录音或加载时禁用
                            : _startRecordingWithTimer,
                        icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                        label: Text(
                          _isRecording 
                            ? '停止录音 ($_remainingTime秒)' 
                            : (kIsWeb ? '开始语音识别' : '开始录音 ($_recordTime秒)'),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          backgroundColor: _isRecording ? Colors.red : null,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 仅在非Web环境下显示评分按钮，或者在已有识别结果时显示
                    if (!kIsWeb && _transcript.isNotEmpty && _recognizedResults.length <= _currentSentenceIndex)
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // 检查是否有录音文件存在，如果没有则不进行音频处理，只使用语音识别结果
                            if (_audioFilePath == null || !await File(_audioFilePath!).exists()) {
                              // 没有录音文件，仅使用已有的转录结果进行评分
                              setState(() {
                                _isLoading = true;
                              });
                              
                              try {
                                // 为当前句子获取评分，使用现有的转录结果
                                double score = await ApiService.getScore(
                                  _sentences[_currentSentenceIndex], 
                                  _transcript
                                );
                                
                                // 更新评分和识别结果
                                if (_scores.length <= _currentSentenceIndex) {
                                  _scores.add(score);
                                } else {
                                  _scores[_currentSentenceIndex] = score;
                                }
                                
                                if (_recognizedResults.length <= _currentSentenceIndex) {
                                  _recognizedResults.add(_transcript);
                                } else {
                                  _recognizedResults[_currentSentenceIndex] = _transcript;
                                }
                                
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('评分完成: ${score.toStringAsFixed(1)}分')),
                                  );
                                }
                              } catch (e) {
                                _logger.severe('评分失败: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('评分失败，请重试')),
                                  );
                                }
                              } finally {
                                if (!_disposed && mounted) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              }
                              return; // 提前结束，不执行下面的音频上传逻辑
                            }
                            
                            // 如果有录音文件，则继续执行音频上传和处理流程
                            try {
                              setState(() {
                                _isLoading = true;
                              });
                              
                              // 上传音频文件到服务器
                              Map<String, dynamic> result = await ApiService.submitAudio(
                                widget.passageIndex,
                                _audioFilePath!,
                              );
                              
                              String accessToken = result['access_token'];
                              
                              // 轮询服务器获取处理结果
                              Map<String, dynamic> processingResult = await _pollForResult(accessToken);
                              
                              // 根据新的API响应格式处理结果
                              String recognizedText = '';
                              double score = 0.0;
                              
                              if (processingResult.containsKey('result')) {
                                recognizedText = processingResult['result'];
                              } else if (processingResult.containsKey('recognized_text')) {
                                recognizedText = processingResult['recognized_text'];
                              }
                              
                              if (processingResult.containsKey('score')) {
                                score = processingResult['score'].toDouble();
                              }
                              
                              // 如果服务器没有返回识别文本，给用户提示
                              if (recognizedText.isEmpty) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('未能识别出语音内容，请重试')),
                                  );
                                }
                                return;
                              }
                              
                              // 保存结果
                              if (_scores.length <= _currentSentenceIndex) {
                                _scores.add(score);
                              } else {
                                _scores[_currentSentenceIndex] = score;
                              }
                              
                              if (_recognizedResults.length <= _currentSentenceIndex) {
                                _recognizedResults.add(recognizedText);
                              } else {
                                _recognizedResults[_currentSentenceIndex] = recognizedText;
                              }
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('录音处理成功，得分: ${score.toStringAsFixed(1)}分')),
                                );
                              }
                              
                              // 更新界面显示识别结果
                              setState(() {
                                _transcript = recognizedText;
                                _isLoading = false;
                              });
                            } catch (e) {
                              _logger.severe('上传音频或获取结果失败: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('处理录音时出现错误: $e')),
                                );
                              }
                            } finally {
                              // 清理录音文件
                              if (_audioFilePath != null) {
                                try {
                                  File audioFile = File(_audioFilePath!);
                                  if (await audioFile.exists()) {
                                    await audioFile.delete();
                                  }
                                } catch (e) {
                                  _logger.warning('删除录音文件失败: $e');
                                }
                                _audioFilePath = null;
                              }
                              
                              if (!_disposed && mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                          icon: const Icon(Icons.star),
                          label: const Text('获取评分'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                    
                    // 导航按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _isProcessing || _isRecording || _isLoading ? null : _previousSentence, // 录音或处理时禁用
                          child: const Text('上一句'),
                        ),
                        ElevatedButton(
                          onPressed: _isProcessing || _isRecording || _isLoading ? null : _nextSentence, // 录音或处理时禁用
                          child: const Text('下一句'),
                        ),
                        ElevatedButton(
                          onPressed: 
                            _currentSentenceIndex == _sentences.length - 1 && _recognizedResults.isNotEmpty
                              ? _submitResults
                              : null,
                          child: const Text('提交结果'),
                        ),
                        // 添加完成练习按钮
                        ElevatedButton(
                          onPressed: _allSentencesCompleted() 
                              ? _finishPractice 
                              : null,
                          child: const Text('完成练习'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// 检查是否所有句子都已经完成评分
  bool _allSentencesCompleted() {
    // 检查是否每个句子都有对应的评分
    return _scores.length == _sentences.length && 
           _scores.every((score) => score > 0);
  }

  /// 完成练习，跳转到结果页面
  void _finishPractice() {
    // 准备结果数据
    List<Map<String, dynamic>> results = [];
    for (int i = 0; i < _sentences.length; i++) {
      results.add({
        'original': _sentences[i],
        'recognized': i < _recognizedResults.length ? _recognizedResults[i] : '',
        'score': i < _scores.length ? _scores[i] : 0,
      });
    }
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(results: results),
        ),
      );
    }
  }
}