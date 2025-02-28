import 'dart:math';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

// 基本思路：
// 1.audioFiles为本地音乐目录，使用 os.listdir 遍历目录，过滤音频格式（如 .mp3），提取文件名称作为播放列表_showPlayList，点击后播放对应的音频文件，使用索引（如数据库索引或哈希表）快速定位歌曲。（延迟加载元数据 :首次扫描时仅记录文件路径，播放时再解析元数据。多线程扫描 : 大型目录使用后台线程加载歌曲，避免界面卡顿。）
// 2.播放列表可能包含上千首歌，首次只加载元数据，滚动时加载歌曲详情（懒加载）。缓存随机序列 : 随机模式下预生成多个播放序列，减少频繁计算。
// 3.播放模式切换。顺序播放 : 直接按列表索引递增，超出后回到开头。随机播放 : 预生成乱序索引列表 (_shuffled_indices)，避免重复播放。单曲循环 : 始终返回当前歌曲，不修改索引。
// 4.**状态持久化。**保存最后一次播放位置和模式到本地文件
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Music Player',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(
                  255, 230, 230, 250)), // Light purple color
        ),
        home: MusicPlayerHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  bool isPlaying = false;
  PlayMode playMode = PlayMode.sequentialRepeat;
  double progress = 0.0;
  int currentSongIndex = 0;
  AudioPlayer audioPlayer = AudioPlayer();
  Duration totalDuration = Duration.zero;
  Duration currentPosition = Duration.zero;
  List<String> audioFiles = [];
  Map<String, String> audioFilePaths = {};
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  List<int> _shuffledIndices = [];

  MyAppState() {
    _initPlayer();
    _scanAudioFiles();
  }

  void _initPlayer() {
    _durationSubscription = audioPlayer.onDurationChanged.listen((duration) {
      totalDuration = duration;
      notifyListeners();
    });

    _positionSubscription = audioPlayer.onPositionChanged.listen((position) {
      currentPosition = position;
      progress = currentPosition.inSeconds /
          (totalDuration.inSeconds == 0 ? 1 : totalDuration.inSeconds);
      notifyListeners();
    });
  }

  Future<void> _scanAudioFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${directory.path}/audio');
    print(audioDir);
    if (await audioDir.exists()) {
      final files = audioDir.listSync();
      for (var file in files) {
        if (file is File && file.path.endsWith('.mp3')) {
          final fileName = file.uri.pathSegments.last;
          audioFiles.add(fileName);
          audioFilePaths[fileName] = file.path;
        }
      }
      _generateShuffledIndices();
      _initializeAudioPlayer();
      notifyListeners();
    }
  }

  void _generateShuffledIndices() {
    _shuffledIndices = List.generate(audioFiles.length, (index) => index);
    _shuffledIndices.shuffle();
  }

  Future<void> _initializeAudioPlayer() async {
    if (audioFiles.isNotEmpty) {
      await audioPlayer.stop();
      final filePath = audioFilePaths[audioFiles[currentSongIndex]];
      if (filePath != null) {
        await audioPlayer.setSourceDeviceFile(filePath);
      }
    }
  }

  void togglePlayPause() async {
    if (isPlaying) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.resume();
    }
    isPlaying = !isPlaying;
    notifyListeners();
  }

  void changeSong() async {
    if (audioFiles.isEmpty) return;

    switch (playMode) {
      case PlayMode.singleRepeat:
        break;
      case PlayMode.sequentialRepeat:
        currentSongIndex = (currentSongIndex + 1) % audioFiles.length;
        break;
      case PlayMode.shuffle:
        int currentShuffleIndex = _shuffledIndices.indexOf(currentSongIndex);
        currentShuffleIndex =
            (currentShuffleIndex + 1) % _shuffledIndices.length;
        currentSongIndex = _shuffledIndices[currentShuffleIndex];
        break;
    }
    await playCurrentSong();
  }

  void nextSong() async {
    if (audioFiles.isEmpty) return;

    currentSongIndex = (currentSongIndex + 1) % audioFiles.length;
    await playCurrentSong();
  }

  void previousSong() async {
    if (audioFiles.isEmpty) return;

    currentSongIndex =
        (currentSongIndex - 1 + audioFiles.length) % audioFiles.length;
    await playCurrentSong();
  }

  Future<void> playCurrentSong() async {
    if (audioFiles.isEmpty) return;

    await audioPlayer.stop();
    final filePath = audioFilePaths[audioFiles[currentSongIndex]];
    if (filePath != null) {
      await audioPlayer.play(DeviceFileSource(filePath));
      isPlaying = true;
      notifyListeners();
    }
  }

  void changePlayMode() {
    switch (playMode) {
      case PlayMode.singleRepeat:
        playMode = PlayMode.sequentialRepeat;
        break;
      case PlayMode.sequentialRepeat:
        playMode = PlayMode.shuffle;
        _generateShuffledIndices();
        break;
      case PlayMode.shuffle:
        playMode = PlayMode.singleRepeat;
        break;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }
}

class MusicPlayerHomePage extends StatefulWidget {
  @override
  _MusicPlayerHomePageState createState() => _MusicPlayerHomePageState();
}

class _MusicPlayerHomePageState extends State<MusicPlayerHomePage> {
  int _page = 0;
  GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  late PageController _pageController; // 添加 PageController

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        items: <Widget>[
          Icon(Icons.music_note, size: 30),
          Icon(Icons.settings, size: 30),
        ],
        onTap: (index) {
          setState(() {
            _page = index;
            _pageController.animateToPage(
              index,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        },
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _page = index;
            final navigationState = _bottomNavigationKey.currentState;
            navigationState?.setPage(index);
          });
        },
        children: [
          PlayerPage(),
          SettingsPage(),
        ],
      ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  @override
  _PlayerPageState createState() => _PlayerPageState();
}

enum PlayMode { singleRepeat, sequentialRepeat, shuffle }

class _PlayerPageState extends State<PlayerPage> {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<MyAppState>(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(18),
              image: DecorationImage(
                image: NetworkImage(
                    "https://i1.sndcdn.com/artworks-000205276174-rkz33n-t500x500.jpg"),
                fit: BoxFit.cover,
              ),
            ),
            child: null,
          ),
          SizedBox(height: 20),
          Text(
            appState.audioFiles.isNotEmpty
                ? appState.audioFiles[appState.currentSongIndex]
                    .split('.')
                    .first
                : '',
            style: TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          SizedBox(height: 30),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Slider(
                value: appState.progress,
                onChanged: (value) {
                  appState.progress = value;
                  final newPosition = Duration(
                      seconds:
                          (value * appState.totalDuration.inSeconds).round());
                  appState.audioPlayer.seek(newPosition);
                  appState.notifyListeners();
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _secondsToDuration(appState.currentPosition.inSeconds),
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      _secondsToDuration(appState.totalDuration.inSeconds),
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous, size: 48),
                onPressed: appState.previousSong,
              ),
              SizedBox(width: 30),
              Container(
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 230, 230, 250),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                      appState.isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 60),
                  onPressed: appState.togglePlayPause,
                ),
              ),
              SizedBox(width: 30),
              IconButton(
                icon: Icon(Icons.skip_next, size: 48),
                onPressed: appState.nextSong,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: _getPlayModeIcon(appState.playMode),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  onPressed: appState.changePlayMode,
                ),
                IconButton(
                  icon: Icon(Icons.playlist_play, size: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  onPressed: () {
                    _showPlaylist(context, appState);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Icon _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.singleRepeat:
        return Icon(Icons.repeat_one, size: 32);
      case PlayMode.sequentialRepeat:
        return Icon(Icons.repeat, size: 32);
      case PlayMode.shuffle:
        return Icon(Icons.shuffle, size: 32);
      default:
        return Icon(Icons.repeat, size: 32);
    }
  }

  void _showPlaylist(BuildContext context, MyAppState appState) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView.builder(
          itemCount: appState.audioFiles.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(appState.audioFiles[index]),
              onTap: () {
                appState.currentSongIndex = index;
                appState.playCurrentSong();
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  String _secondsToDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class LyricsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<String> lyrics = [
      "The club isn’t the best place to find a lover",
      "So the bar is where I go",
    ];
    return ListView.builder(
      itemCount: lyrics.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 30.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              lyrics[index],
              style: TextStyle(
                fontSize: 18,
                color: index == 0 ? Colors.blueAccent : Colors.black87,
                fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

// 添加SettingsPage类
class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _backgroundPlay = true;
  String _audioQuality = '高质量';
  bool _wifiOnly = true;
  bool _autoDownload = false;
  double _cacheSize = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    // 模拟加载缓存大小
    setState(() {
      _cacheSize = 156.4; // 模拟值，单位MB
    });
  }

  Future<void> _clearCache() async {
    // 模拟清除缓存操作
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清除缓存'),
        content: Text('缓存清除中...'),
      ),
    );

    await Future.delayed(Duration(seconds: 1));

    Navigator.pop(context);
    setState(() {
      _cacheSize = 0.0;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('缓存已清除')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('播放设置'),
          SwitchListTile(
            title: Text('后台播放'),
            subtitle: Text('应用退出后继续播放音乐'),
            value: _backgroundPlay, // 后台播放默认开启
            onChanged: (value) {
              setState(() {
                _backgroundPlay = value; // 更新状态
              });
              // 这里可以添加后台播放的具体实现逻辑
            },
          ),
          ListTile(
            title: Text('音频质量'),
            subtitle: Text(_audioQuality),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showQualityOptions();
            },
          ),
          _buildSectionHeader('下载设置'),
          SwitchListTile(
            title: Text('仅在WiFi下载'),
            subtitle: Text('使用移动网络时不下载音乐'),
            value: _wifiOnly, // 使用类成员变量跟踪状态
            onChanged: (value) {
              setState(() {
                _wifiOnly = value; // 更新状态
              });
            },
          ),
          SwitchListTile(
            title: Text('自动下载'),
            subtitle: Text('自动下载收藏的歌曲'),
            value: _autoDownload,
            onChanged: (value) {
              setState(() {
                _autoDownload = value;
              });
            },
          ),
          _buildSectionHeader('存储'),
          ListTile(
            title: Text('缓存大小'),
            subtitle: Text('${_cacheSize.toStringAsFixed(1)} MB'),
            trailing: TextButton(
              child: Text('清除'),
              onPressed: _clearCache,
            ),
          ),
          _buildSectionHeader('外观'),
          SwitchListTile(
            title: Text('深色模式'),
            subtitle: Text('切换应用主题'),
            value: _darkMode,
            onChanged: (value) {
              setState(() {
                _darkMode = value;
              });
              // 这里应该实现主题切换逻辑
            },
          ),
          _buildSectionHeader('关于'),
          ListTile(
            title: Text('版本'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            title: Text('检查更新'),
            trailing: Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('已是最新版本')));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showQualityOptions() {
    final options = ['标准质量', '高质量', '无损质量'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('选择音频质量'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              return RadioListTile<String>(
                title: Text(option),
                value: option,
                groupValue: _audioQuality,
                onChanged: (value) {
                  setState(() {
                    _audioQuality = value!;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
