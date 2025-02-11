import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(MyApp());
}

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
  PlayMode playMode = PlayMode.sequentialRepeat; // Initialize the play mode
  double progress = 0.0;
  final String currentSong = "Shape of You";
  final String coverImageUrl =
      "https://i1.sndcdn.com/artworks-000205276174-rkz33n-t500x500.jpg";
  final String currentArtist = "Ed Sheeran";
  int currentSongIndex = 0; // Track the index of the current song
  AudioPlayer audioPlayer = AudioPlayer(); // Create an AudioPlayer instance
  Duration totalDuration = Duration.zero; // Change to Duration type
  Duration currentPosition = Duration.zero;
  final List<String> audioFiles = [
    // 'assets/audio/Ed Sheeran - Shape Of You (Lyrics).mp3',
    'https://cdn.inpm.top/Ed%20Sheeran%20-%20Shape%20Of%20You%20%28Lyrics%29.mp3',
    'https://cdn.inpm.top/%E6%8E%A8%E5%BC%80%E4%B8%96%E7%95%8C%E7%9A%84%E9%97%A8%20-%20%E6%9D%A8%E4%B9%83%E6%96%87%E3%80%90Hi-Res%E6%97%A0%E6%8D%9F%E9%9F%B3%E8%B4%A8%E3%80%91%20.mp3',
    'https://cdn.inpm.top/%E3%80%904K60FPS%E3%80%91%E5%91%A8%E6%9D%B0%E4%BC%A6%E3%80%8A%E6%9A%97%E5%8F%B7%E3%80%8B%20%E7%A5%9E%E7%BA%A7%E7%8E%B0%E5%9C%BA%EF%BC%81The%20one%E6%BC%94%E5%94%B1%E4%BC%9Alive%20-%20001%20-%20%E3%80%904K60FPS%E3%80%91%E5%91%A8%E6%9D%B0%E4%BC%A6%E3%80%8A%E6%9A%97%E5%8F%B7%E3%80%8B%20%E7%A5%9E%E7%BA%A7%E7%8E%B0%E5%9C%BA%EF%BC%81The%20one%E6%BC%94%E5%94%B1%E4%BC%9Alive.mp3',
    'https://cdn.inpm.top/%E3%80%904K60FPS%E3%80%91%E6%96%B9%E5%A4%A7%E5%90%8C%E3%80%8ALove%20Song%E3%80%8B%E4%B8%87%E4%BA%BA%E5%A4%A7%E5%90%88%E5%94%B1%E7%8E%B0%E5%9C%BA%EF%BC%81%E4%B8%96%E7%95%8C%E5%90%8D%E7%94%BB%20-%20001%20-%20%E3%80%904K60FPS%E3%80%91%E6%96%B9%E5%A4%A7%E5%90%8C%E3%80%8ALove%20Song%E3%80%8B%E4%B8%87%E4%BA%BA%E5%A4%A7%E5%90%88%E5%94%B1%E7%8E%B0%E5%9C%BA%EF%BC%81%E4%B8%96%E7%95%8C%E5%90%8D%E7%94%BB.mp3'
    // Add more audio files as needed
  ];

  @override
  void initState() {
    super.initState();
    // Load the first audio file and get its duration
    _loadFirstAudioFile();

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
  }

  // Method to load the first audio file and set its duration
  Future<void> _loadFirstAudioFile() async {
    await audioPlayer.setSourceUrl(audioFiles[currentSongIndex]);
    totalDuration = await audioPlayer.getDuration() ?? Duration.zero;
  }

  @override
  void dispose() {
    // audioPlayer.dispose(); // Dispose of the audio player when not needed
    super.dispose();
  }

  void _showPlaylist(BuildContext context) {
    final random = Random();
    final List<String> dummySongs = [
      "Song A",
      "Song B",
      "Song C",
      "Song D",
      "Song E"
    ];
    // Shuffle the list and take 3 random songs
    final List<String> selectedSongs =
        (dummySongs..shuffle(random)).take(3).toList();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView.builder(
          itemCount: selectedSongs.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(selectedSongs[index]),
            );
          },
        );
      },
    );
  }

  // Method to toggle play and pause
  void _togglePlayPause() async {
    if (isPlaying) {
      await audioPlayer.pause();
    } else {
      await audioPlayer
          .resume(); // Use the helper method to play the current song
    }

    setState(() {
      isPlaying = !isPlaying;
    });
    // Here you can add logic to play or pause the audio player
  }

  // Method to change the song based on the direction
  void _changeSong() async {
    switch (playMode) {
      case PlayMode.singleRepeat:
        // Do nothing, as the current song will repeat
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

  // Method to switch to the next song in the list
  void _nextSong() async {
    currentSongIndex = (currentSongIndex + 1) % audioFiles.length;
    await _playCurrentSong();
  }

  // Method to switch to the previous song in the list
  void _previousSong() async {
    currentSongIndex =
        (currentSongIndex - 1 + audioFiles.length) % audioFiles.length;
    await _playCurrentSong();
  }

  // Helper method to play the current song
  Future<void> _playCurrentSong() async {
    await audioPlayer.stop(); // Stop the previous song
    await audioPlayer.play(
        UrlSource(audioFiles[currentSongIndex])); // Ensure this is correct
    setState(() {
      isPlaying = true;
    });
  }

  String get currentTime {
    final totalSeconds = _durationToSeconds(totalDuration as String);
    final currentSeconds = (totalSeconds * progress).round();
    return _secondsToDuration(currentSeconds);
  }

  int _durationToSeconds(String duration) {
    final parts = duration.split(':');
    final minutes = int.parse(parts[0]);
    final seconds = int.parse(parts[1]);
    return minutes * 60 + seconds;
  }

  String _secondsToDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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
                image: NetworkImage(coverImageUrl),
                fit: BoxFit.cover,
              ),
            ),
            child: coverImageUrl.isEmpty
                ? Icon(Icons.music_note, size: 185)
                : null,
          ),
          SizedBox(height: 20),
          Text(currentSong, style: TextStyle(fontSize: 24)),
          SizedBox(height: 10),
          Text(currentArtist, style: TextStyle(fontSize: 18)),
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
                  icon: getPlayModeIcon(), // Icon for play mode
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  onPressed: () {
                    // Logic to switch play mode
                    _changeSong();
                    setState(() {
                      playMode = PlayMode.values[
                          (playMode.index + 1) % PlayMode.values.length];
                    });
                  },
                ),
                IconButton(
                  icon:
                      Icon(Icons.playlist_play, size: 36), // Icon for playlist
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
