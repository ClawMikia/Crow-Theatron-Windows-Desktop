/// A segment of the video timeline to be automatically skipped during playback.
/// Port of `data/TimelineSkip.kt`.
class TimelineSkip {
  final int id;
  final int videoId;
  final int startMs;
  final int endMs;
  final String label;
  final int createdAt;

  const TimelineSkip({
    this.id = 0,
    required this.videoId,
    required this.startMs,
    required this.endMs,
    this.label = 'Skip',
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id == 0 ? null : id,
        'video_id': videoId,
        'start_ms': startMs,
        'end_ms': endMs,
        'label': label,
        'created_at': createdAt,
      };

  factory TimelineSkip.fromMap(Map<String, Object?> m) => TimelineSkip(
        id: m['id'] as int,
        videoId: m['video_id'] as int,
        startMs: m['start_ms'] as int,
        endMs: m['end_ms'] as int,
        label: m['label'] as String? ?? 'Skip',
        createdAt: m['created_at'] as int,
      );
}
