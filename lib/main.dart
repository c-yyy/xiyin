import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

// 请要下面要求帮我完善代码：
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

class MyAppState extends ChangeNotifier {}

class MusicPlayerHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        children: [
          PlayerPage(),
          LyricsPage(),
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
  bool isPlaying = false;
  PlayMode playMode = PlayMode.sequentialRepeat;
  double progress = 0.0;
  int currentSongIndex = 0;
  AudioPlayer audioPlayer = AudioPlayer();
  Duration totalDuration = Duration.zero;
  Duration currentPosition = Duration.zero;
  List<String> audioFiles = [];
  Map<String, String> audioFilePaths = {};

  @override
  @override
  void initState() {
    super.initState();
    _scanAudioFiles();
    audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        totalDuration = duration;
      });
    });

    audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        currentPosition = position;
        progress = currentPosition.inSeconds /
            (totalDuration.inSeconds == 0 ? 1 : totalDuration.inSeconds);
      });
    });

    _initializeAudioPlayer();
  }

  Future<void> _initializeAudioPlayer() async {
    if (currentSongIndex == 0) {
      await audioPlayer.stop();
      final filePath = audioFilePaths[audioFiles[currentSongIndex]];
      if (filePath != null) {
        await audioPlayer.setSourceDeviceFile(filePath);
      }
    }
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
      setState(() {});
    }
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  void _showPlaylist(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView.builder(
          itemCount: audioFiles.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(audioFiles[index]),
              onTap: () {
                currentSongIndex = index;
                _playCurrentSong();
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _togglePlayPause() async {
    if (isPlaying) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.resume();
    }

    setState(() {
      isPlaying = !isPlaying;
    });
  }

  void _changeSong() async {
    switch (playMode) {
      case PlayMode.singleRepeat:
        break;
      case PlayMode.sequentialRepeat:
        currentSongIndex = (currentSongIndex + 1) % audioFiles.length;
        break;
      case PlayMode.shuffle:
        currentSongIndex = Random().nextInt(audioFiles.length);
        break;
    }
    await _playCurrentSong();
  }

  void _nextSong() async {
    currentSongIndex = (currentSongIndex + 1) % audioFiles.length;
    await _playCurrentSong();
  }

  void _previousSong() async {
    currentSongIndex =
        (currentSongIndex - 1 + audioFiles.length) % audioFiles.length;
    await _playCurrentSong();
  }

  Future<void> _playCurrentSong() async {
    await audioPlayer.stop();
    final filePath = audioFilePaths[audioFiles[currentSongIndex]];
    if (filePath != null) {
      await audioPlayer.play(DeviceFileSource(filePath));
      setState(() {
        isPlaying = true;
      });
    }
  }

  Icon getPlayModeIcon() {
    switch (playMode) {
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

  @override
  Widget build(BuildContext context) {
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
            audioFiles.isNotEmpty
                ? audioFiles[currentSongIndex].split('.').first
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
                value: progress,
                onChanged: (value) {
                  setState(() {
                    progress = value;
                    final newPosition = Duration(
                        seconds: (value * totalDuration.inSeconds).round());
                    audioPlayer.seek(newPosition);
                  });
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _secondsToDuration(currentPosition.inSeconds),
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      _secondsToDuration(totalDuration.inSeconds),
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
                onPressed: _previousSong,
              ),
              SizedBox(width: 30),
              Container(
                decoration: BoxDecoration(
                  color: Color.fromARGB(255, 230, 230, 250),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 60),
                  onPressed: _togglePlayPause,
                ),
              ),
              SizedBox(width: 30),
              IconButton(
                icon: Icon(Icons.skip_next, size: 48),
                onPressed: _nextSong,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: getPlayModeIcon(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  onPressed: () {
                    _changeSong();
                    setState(() {
                      playMode = PlayMode.values[
                          (playMode.index + 1) % PlayMode.values.length];
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.playlist_play, size: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  onPressed: () {
                    _showPlaylist(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
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
