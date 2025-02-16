// providers/player_provider.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';

enum PlayMode { singleRepeat, sequentialRepeat, shuffle }

class PlayerProvider extends ChangeNotifier {
  List<Song> _songs = [];
  int _currentIndex = 0;
  PlayMode _playMode = PlayMode.sequentialRepeat;
  List<int>? _shuffleIndices;

  List<Song> get songs => _songs;
  int get currentIndex => _currentIndex;
  int? _currentShuffleIndex; // 新增状态变量
  PlayMode get playMode => _playMode;

  Future<void> scanLocalMusic() async {
    final dir = await getApplicationDocumentsDirectory();
    _songs = await _scanDirectory(dir.path);
    notifyListeners();
  }

  Future<List<Song>> _scanDirectory(String path) async {
    final dir = Directory(path);
    return await dir
        .list()
        .where((file) => ['mp3', 'wav', 'flac']
            .contains(file.path.split('.').last.toLowerCase()))
        .map((file) => Song.fromFilePath(file.path))
        .toList();
  }

  void switchPlayMode() {
    _playMode = PlayMode.values[(_playMode.index + 1) % PlayMode.values.length];
    _shuffleIndices = null;
    notifyListeners();
  }

  // 随机列表生成
  List<int> _generateShuffleIndices() {
    return List.generate(_songs.length, (i) => i)..shuffle();
  }

  void nextSong() {
    if (_playMode == PlayMode.singleRepeat) return;

    switch (_playMode) {
      case PlayMode.sequentialRepeat:
        _currentIndex = (_currentIndex + 1) % _songs.length;
        break;
      case PlayMode.shuffle:
        if (_shuffleIndices == null) {
          _shuffleIndices = _generateShuffleIndices();
          _currentShuffleIndex = 0;
        } else {
          _currentShuffleIndex =
              (_currentShuffleIndex! + 1) % _shuffleIndices!.length;
        }
        _currentIndex = _shuffleIndices![_currentShuffleIndex!];
        break;
      default:
        _currentIndex++;
    }
    notifyListeners();
  }

  void playSpecific(int index) {
    _currentIndex = index;
    notifyListeners();
  }
}
