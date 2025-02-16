// models/song.dart
class Song {
  final String filePath;
  final String title;
  final String artist;

  Song({
    required this.filePath,
    this.title = "未知标题",
    this.artist = "未知艺术家",
  });

  static Song fromFilePath(String path) {
    final filename = path.split('/').last.split('.').first;
    return Song(
      filePath: path,
      title: filename,
    );
  }
}
