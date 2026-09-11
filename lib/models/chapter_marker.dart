/// A named timestamp bookmark stored per video.
/// Port of `data/ChapterMarker.kt`.
class ChapterMarker {
  final int id;
  final int videoId;
  final int positionMs;
  final String label;
  final bool isAutoDetected;
  final int createdAt;

  const ChapterMarker({
    this.id = 0,
    required this.videoId,
    required this.positionMs,
    required this.label,
    this.isAutoDetected = false,
    required this.createdAt,
  });

  ChapterMarker copyWith({int? id, int? videoId, int? positionMs, String? label}) => ChapterMarker(
        id: id ?? this.id,
        videoId: videoId ?? this.videoId,
        positionMs: positionMs ?? this.positionMs,
        label: label ?? this.label,
        isAutoDetected: isAutoDetected,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id == 0 ? null : id,
        'video_id': videoId,
        'position_ms': positionMs,
        'label': label,
        'is_auto': isAutoDetected ? 1 : 0,
        'created_at': createdAt,
      };

  factory ChapterMarker.fromMap(Map<String, Object?> m) => ChapterMarker(
        id: m['id'] as int,
        videoId: m['video_id'] as int,
        positionMs: m['position_ms'] as int,
        label: m['label'] as String,
        isAutoDetected: (m['is_auto'] as int? ?? 0) == 1,
        createdAt: m['created_at'] as int,
      );
}
