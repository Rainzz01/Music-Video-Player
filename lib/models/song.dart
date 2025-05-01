class Song {
  final String songName;
  final String artistName;
  final String albumArtImagePath;
  final String audioPath;
  final String? album;
  final String? genre;
  final String fileHash;

  Song({
    required this.songName,
    required this.artistName,
    required this.albumArtImagePath,
    required this.audioPath,
    this.album,
    this.genre,
    required this.fileHash,
  });

  Song.empty()
      : songName = '',
        artistName = '',
        albumArtImagePath = 'assets/images/default_art.png',
        audioPath = '',
        album = null,
        genre = null,
        fileHash = '';
}