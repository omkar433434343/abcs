import 'dart:typed_data';
import 'feature_schema.dart';

class SlidingWindowBuffer {
  final int windowSize;
  final List<Float32List> _buffer;
  final List<Float32List> _result;
  int _head = 0;
  int _count = 0;

  SlidingWindowBuffer({this.windowSize = ISLFeatureSchema.windowSize})
    : _buffer = List.filled(windowSize, Float32List(0)),
      _result = List.filled(windowSize, Float32List(0));

  void push(Float32List frame) {
    _buffer[_head] = Float32List.fromList(frame);
    _head = (_head + 1) % windowSize;
    if (_count < windowSize) _count++;
  }

  bool get isFull => _count == windowSize;
  int get count => _count;

  List<Float32List> get window {
    if (_count == 0) return List.unmodifiable(const <Float32List>[]);

    if (_count < windowSize) {
      // Buffer not yet full: valid entries occupy indices 0.._count-1
      // _head points to the next write slot, which equals _count here
      for (int i = 0; i < _count; i++) {
        _result[i] = _buffer[i];
      }
      return List.unmodifiable(_result.sublist(0, _count));
    }

    // Buffer full: oldest entry is at _head, newest is at (_head - 1) % windowSize
    for (int i = 0; i < windowSize; i++) {
      _result[i] = _buffer[(_head + i) % windowSize];
    }
    return List.unmodifiable(_result);
  }

  List<Float32List> get paddedWindow {
    if (_count == 0) return List.unmodifiable(const <Float32List>[]);

    final current = window;
    if (current.length == windowSize) return current;

    final first = current.first;
    final missing = windowSize - current.length;
    for (int i = 0; i < missing; i++) {
      _result[i] = first;
    }
    for (int i = 0; i < current.length; i++) {
      _result[missing + i] = current[i];
    }
    return List.unmodifiable(_result);
  }

  void clear() {
    _head = 0;
    _count = 0;
  }
}
