import 'crop_mode.dart';
import 'enhancement_mode.dart';
import 'eq_preset.dart';

/// Port of `data/VideoEntity.kt`. On desktop, `uriString` /
/// `sourceUriString` are absolute filesystem paths rather than
/// Android SAF `content://` URIs.
class VideoEntity {
  final int id;
  final String uriString;
  final String? sourceUriString;
  final String title;
  final String folderGroup;
  final int durationMs;
  final int sizeBytes;
  final int positionMs;
  final int pitchSemitones;
  final int trimStartMs;
  final int trimEndMs;
  final bool favorite;
  final int seekJumpSec;
  final bool autoPlayNext;
  final bool shufflePlaylist;
  final bool loopPlayback;
  final EnhancementMode enhancement;
  final int lastPlayedAt;
  final double playbackSpeed;
  final double volumeLevel;
  // Video enhancement sliders
  final double brightness;
  final double contrast;
  final double saturation;
  final double hue;
  final double sharpness;
  // Display
  final double zoomLevel;
  final CropMode cropMode;
  // Audio
  final double audioBoost;
  final EqPreset eqPreset;
  // Subtitle
  final int subtitleTrackIndex;
  final int subtitleOffsetMs;
  final double subtitleSizeSp;
  final bool subtitleBold;
  final int subtitleBackgroundAlpha;
  // Orientation (kept for parity; unused on desktop)
  final int preferredOrientation;

  const VideoEntity({
    this.id = 0,
    required this.uriString,
    this.sourceUriString,
    required this.title,
    required this.folderGroup,
    this.durationMs = 0,
    this.sizeBytes = 0,
    this.positionMs = 0,
    this.pitchSemitones = 0,
    this.trimStartMs = 0,
    this.trimEndMs = 0,
    this.favorite = false,
    this.seekJumpSec = 10,
    this.autoPlayNext = false,
    this.shufflePlaylist = false,
    this.loopPlayback = false,
    this.enhancement = EnhancementMode.none,
    this.lastPlayedAt = 0,
    this.playbackSpeed = 1.0,
    this.volumeLevel = 1.0,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.hue = 0,
    this.sharpness = 0,
    this.zoomLevel = 1,
    this.cropMode = CropMode.fit,
    this.audioBoost = 1,
    this.eqPreset = EqPreset.flat,
    this.subtitleTrackIndex = -1,
    this.subtitleOffsetMs = 0,
    this.subtitleSizeSp = 16,
    this.subtitleBold = false,
    this.subtitleBackgroundAlpha = 128,
    this.preferredOrientation = -1,
  });

  VideoEntity copyWith({
    int? id,
    String? uriString,
    String? sourceUriString,
    String? title,
    String? folderGroup,
    int? durationMs,
    int? sizeBytes,
    int? positionMs,
    int? pitchSemitones,
    int? trimStartMs,
    int? trimEndMs,
    bool? favorite,
    int? seekJumpSec,
    bool? autoPlayNext,
    bool? shufflePlaylist,
    bool? loopPlayback,
    EnhancementMode? enhancement,
    int? lastPlayedAt,
    double? playbackSpeed,
    double? volumeLevel,
    double? brightness,
    double? contrast,
    double? saturation,
    double? hue,
    double? sharpness,
    double? zoomLevel,
    CropMode? cropMode,
    double? audioBoost,
    EqPreset? eqPreset,
    int? subtitleTrackIndex,
    int? subtitleOffsetMs,
    double? subtitleSizeSp,
    bool? subtitleBold,
    int? subtitleBackgroundAlpha,
    int? preferredOrientation,
  }) {
    return VideoEntity(
      id: id ?? this.id,
      uriString: uriString ?? this.uriString,
      sourceUriString: sourceUriString ?? this.sourceUriString,
      title: title ?? this.title,
      folderGroup: folderGroup ?? this.folderGroup,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      positionMs: positionMs ?? this.positionMs,
      pitchSemitones: pitchSemitones ?? this.pitchSemitones,
      trimStartMs: trimStartMs ?? this.trimStartMs,
      trimEndMs: trimEndMs ?? this.trimEndMs,
      favorite: favorite ?? this.favorite,
      seekJumpSec: seekJumpSec ?? this.seekJumpSec,
      autoPlayNext: autoPlayNext ?? this.autoPlayNext,
      shufflePlaylist: shufflePlaylist ?? this.shufflePlaylist,
      loopPlayback: loopPlayback ?? this.loopPlayback,
      enhancement: enhancement ?? this.enhancement,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      volumeLevel: volumeLevel ?? this.volumeLevel,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      hue: hue ?? this.hue,
      sharpness: sharpness ?? this.sharpness,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      cropMode: cropMode ?? this.cropMode,
      audioBoost: audioBoost ?? this.audioBoost,
      eqPreset: eqPreset ?? this.eqPreset,
      subtitleTrackIndex: subtitleTrackIndex ?? this.subtitleTrackIndex,
      subtitleOffsetMs: subtitleOffsetMs ?? this.subtitleOffsetMs,
      subtitleSizeSp: subtitleSizeSp ?? this.subtitleSizeSp,
      subtitleBold: subtitleBold ?? this.subtitleBold,
      subtitleBackgroundAlpha: subtitleBackgroundAlpha ?? this.subtitleBackgroundAlpha,
      preferredOrientation: preferredOrientation ?? this.preferredOrientation,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id == 0 ? null : id,
        'uri': uriString,
        'source_uri': sourceUriString,
        'title': title,
        'folder_group': folderGroup,
        'duration_ms': durationMs,
        'size_bytes': sizeBytes,
        'position_ms': positionMs,
        'pitch_semitones': pitchSemitones,
        'trim_start_ms': trimStartMs,
        'trim_end_ms': trimEndMs,
        'favorite': favorite ? 1 : 0,
        'seek_jump_sec': seekJumpSec,
        'auto_play_next': autoPlayNext ? 1 : 0,
        'loop_playback': loopPlayback ? 1 : 0,
        'enhancement': enhancement.storageKey,
        'last_played_at': lastPlayedAt,
        'playback_speed': playbackSpeed,
        'volume_level': volumeLevel,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'hue': hue,
        'sharpness': sharpness,
        'zoom_level': zoomLevel,
        'crop_mode': cropMode.storageKey,
        'audio_boost': audioBoost,
        'eq_preset': eqPreset.storageKey,
        'subtitle_track': subtitleTrackIndex,
        'subtitle_offset_ms': subtitleOffsetMs,
        'subtitle_size_sp': subtitleSizeSp,
        'subtitle_bold': subtitleBold ? 1 : 0,
        'subtitle_bg_alpha': subtitleBackgroundAlpha,
        'preferred_orientation': preferredOrientation,
      };

  factory VideoEntity.fromMap(Map<String, Object?> m) => VideoEntity(
        id: m['id'] as int? ?? 0,
        uriString: m['uri'] as String,
        sourceUriString: m['source_uri'] as String?,
        title: m['title'] as String,
        folderGroup: m['folder_group'] as String,
        durationMs: m['duration_ms'] as int? ?? 0,
        sizeBytes: m['size_bytes'] as int? ?? 0,
        positionMs: m['position_ms'] as int? ?? 0,
        pitchSemitones: m['pitch_semitones'] as int? ?? 0,
        trimStartMs: m['trim_start_ms'] as int? ?? 0,
        trimEndMs: m['trim_end_ms'] as int? ?? 0,
        favorite: (m['favorite'] as int? ?? 0) == 1,
        seekJumpSec: m['seek_jump_sec'] as int? ?? 10,
        autoPlayNext: (m['auto_play_next'] as int? ?? 0) == 1,
        loopPlayback: (m['loop_playback'] as int? ?? 0) == 1,
        enhancement: EnhancementMode.fromKey(m['enhancement'] as String?),
        lastPlayedAt: m['last_played_at'] as int? ?? 0,
        playbackSpeed: (m['playback_speed'] as num?)?.toDouble() ?? 1.0,
        volumeLevel: (m['volume_level'] as num?)?.toDouble() ?? 1.0,
        brightness: (m['brightness'] as num?)?.toDouble() ?? 0,
        contrast: (m['contrast'] as num?)?.toDouble() ?? 1,
        saturation: (m['saturation'] as num?)?.toDouble() ?? 1,
        hue: (m['hue'] as num?)?.toDouble() ?? 0,
        sharpness: (m['sharpness'] as num?)?.toDouble() ?? 0,
        zoomLevel: (m['zoom_level'] as num?)?.toDouble() ?? 1,
        cropMode: CropMode.fromKey(m['crop_mode'] as String?),
        audioBoost: (m['audio_boost'] as num?)?.toDouble() ?? 1,
        eqPreset: EqPreset.fromKey(m['eq_preset'] as String?),
        subtitleTrackIndex: m['subtitle_track'] as int? ?? -1,
        subtitleOffsetMs: m['subtitle_offset_ms'] as int? ?? 0,
        subtitleSizeSp: (m['subtitle_size_sp'] as num?)?.toDouble() ?? 16,
        subtitleBold: (m['subtitle_bold'] as int? ?? 0) == 1,
        subtitleBackgroundAlpha: m['subtitle_bg_alpha'] as int? ?? 128,
        preferredOrientation: m['preferred_orientation'] as int? ?? -1,
      );
}
