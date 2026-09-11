/// Port of the `playlists` / `playlist_videos` tables used by
/// `PlaylistListActivity.kt`.
class Playlist {
  final int id;
  final String title;
  final int createdAt;

  const Playlist({this.id = 0, required this.title, required this.createdAt});

  Map<String, Object?> toMap() => {
        'id': id == 0 ? null : id,
        'title': title,
        'created_at': createdAt,
      };

  factory Playlist.fromMap(Map<String, Object?> m) => Playlist(
        id: m['id'] as int,
        title: m['title'] as String,
        createdAt: m['created_at'] as int,
      );
}
