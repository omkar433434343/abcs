import 'dart:async';
import 'dart:isolate';
import 'package:camera/camera.dart';

class CameraFramePipeline {
  final CameraController _controller;
  bool _isProcessing = false;
  int _droppedFrameCount = 0;
  SendPort? _frameSendPort;

  CameraFramePipeline(this._controller);

  void attachSendPort(SendPort port) {
    _frameSendPort = port;
  }

  Future<void> startStreaming() async {
    if (_frameSendPort == null) {
      throw StateError('attachSendPort must be called before startStreaming');
    }
    await _controller.startImageStream(_onFrame);
  }

  void _onFrame(CameraImage image) {
    if (_isProcessing) {
      _droppedFrameCount++;
      assert(() {
        if (_droppedFrameCount % 30 == 0) {
          // ignore: avoid_print
          print('[CameraFramePipeline] Dropped $_droppedFrameCount frames');
        }
        return true;
      }());
      return;
    }

    _isProcessing = true;
    _frameSendPort!.send(image);
  }

  void signalFrameProcessed() {
    _isProcessing = false;
  }

  Future<void> stopStreaming() async {
    await _controller.stopImageStream();
    _isProcessing = false;
    _droppedFrameCount = 0;
  }

  int get droppedFrameCount => _droppedFrameCount;
}
