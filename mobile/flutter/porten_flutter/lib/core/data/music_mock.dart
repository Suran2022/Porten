/*
 * 悦音乐曲目数据与 LRC 歌词解析（100% 对齐 Web 端 data/music.ts 与
 * components/music/MusicView.tsx 的 parseLrc）。
 *
 * 结构：曲目元数据（标题/副标题/艺人/时长/进度/音质/喜欢/评论/背景渐变/
 * 黑胶色/封面标签/歌词/音源）。背景渐变按 Web bgGradient 的 180deg 线性
 * 渐变逐色标转录；状态栏取渐变色首、底部工具栏取渐变色末
 * （对齐 Web topColor/bottomColor 取色规则）。
 */

import 'dart:convert';

import 'package:flutter/material.dart';

/// 歌词行。
class LyricLine {
  const LyricLine({required this.time, required this.text});

  /// 时间（秒）。
  final double time;

  /// 歌词文本。
  final String text;
}

/// 曲目（字段同 Web MusicTrack）。
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    this.subtitle,
    required this.artist,
    required this.duration,
    required this.currentTime,
    required this.quality,
    required this.likes,
    required this.comments,
    required this.gradientColors,
    required this.gradientStops,
    required this.vinylColor,
    required this.coverLabel,
    this.lrcSrc,
    this.audioSrc,
  });

  final String id;
  final String title;

  /// 副标题（如 Cover 晴愔）。
  final String? subtitle;
  final String artist;

  /// 总时长（秒，静态 mock 值）。
  final int duration;

  /// 静态进度（秒，无音源曲目的兜底进度）。
  final int currentTime;
  final String quality;
  final String likes;
  final String comments;

  /// 背景渐变色标（按 Web bgGradient 顺序）。
  final List<Color> gradientColors;

  /// 背景渐变色标位置（0-1）。
  final List<double> gradientStops;

  /// 黑胶外圈色。
  final Color vinylColor;

  /// 无封面图时的中心文字标签。
  final String coverLabel;

  /// 歌词文件路径（Flutter asset 路径）。
  final String? lrcSrc;

  /// 音频文件路径（Flutter asset 路径），无则不可播放。
  final String? audioSrc;

  /// 是否具备音源（对齐 Web audioSrc 语义：无音源不可真实播放，
  /// 进度/时长用静态数据兜底）。
  bool get hasAudio => audioSrc != null;

  /// 页面背景渐变（Web bgGradient：180deg 线性渐变）。
  LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors,
        stops: gradientStops,
      );

  /// 状态栏取色（Web topColor = 渐变第一个 hex）。
  Color get statusBarColor => gradientColors.first;

  /// 底部工具栏取色（Web bottomColor = 渐变最后一个 hex）。
  Color get bottomBarColor => gradientColors.last;
}

/// 曲目列表（顺序同 Web MUSIC_TRACKS；仅第 1 首具备音源与歌词）。
const List<MusicTrack> kMusicTracks = <MusicTrack>[
  MusicTrack(
    id: '1',
    title: '眉间雪',
    subtitle: 'Cover 晴愔',
    artist: '锦零',
    duration: 269,
    currentTime: 109,
    quality: '极高音质',
    likes: '14w+',
    comments: '999+',
    gradientColors: <Color>[
      Color(0xFF3D2817),
      Color(0xFF2F1F12),
      Color(0xFF231710),
      Color(0xFF1A1108),
      Color(0xFF1A1108),
    ],
    gradientStops: <double>[0, 0.3, 0.6, 0.85, 1],
    vinylColor: Color(0xFF1A1A1A),
    coverLabel: 'bmb',
    lrcSrc: 'assets/musice-back1.lrc',
    audioSrc: 'assets/musice-back1.mp3',
  ),
  MusicTrack(
    id: '2',
    title: '深海',
    subtitle: 'Original Mix',
    artist: '蓝调',
    duration: 225,
    currentTime: 80,
    quality: '无损',
    likes: '8.5w',
    comments: '420',
    gradientColors: <Color>[
      Color(0xFF2C3E50),
      Color(0xFF243340),
      Color(0xFF1A2733),
      Color(0xFF0F1820),
      Color(0xFF0F1820),
    ],
    gradientStops: <double>[0, 0.3, 0.6, 0.85, 1],
    vinylColor: Color(0xFF0E1116),
    coverLabel: 'ocn',
  ),
  MusicTrack(
    id: '3',
    title: '黄昏的车站',
    subtitle: 'Acoustic',
    artist: '云雀',
    duration: 312,
    currentTime: 145,
    quality: '极高音质',
    likes: '5.2w',
    comments: '186',
    gradientColors: <Color>[
      Color(0xFF4A3528),
      Color(0xFF3D2C20),
      Color(0xFF322318),
      Color(0xFF1F1410),
      Color(0xFF1F1410),
    ],
    gradientStops: <double>[0, 0.3, 0.6, 0.85, 1],
    vinylColor: Color(0xFF181410),
    coverLabel: 'stn',
  ),
  MusicTrack(
    id: '4',
    title: '雨后',
    subtitle: 'Piano Ver.',
    artist: '小屿',
    duration: 198,
    currentTime: 60,
    quality: '标准',
    likes: '2.3w',
    comments: '92',
    gradientColors: <Color>[
      Color(0xFF3A3530),
      Color(0xFF312C29),
      Color(0xFF252220),
      Color(0xFF161413),
      Color(0xFF161413),
    ],
    gradientStops: <double>[0, 0.3, 0.6, 0.85, 1],
    vinylColor: Color(0xFF131312),
    coverLabel: 'rn',
  ),
];

/// 情绪音乐馆轮播文案（对齐 Web moodTexts）。
const List<String> kMusicMoodTexts = <String>[
  '情绪音乐馆：来自网易云',
  '情绪音乐馆：来自锦零',
];

/// 分享文案池（对齐 Web shareTexts，每次分享随机选取一条）。
const List<String> kMusicShareTexts = <String>[
  '这首情绪音乐太好听了，快来 Porten 一起聆听吧～',
  '在 Porten 情绪音乐馆发现一首宝藏歌曲，分享给你！',
  '让音乐治愈心灵，来 Porten 情绪音乐馆一起感受～',
  '好听到单曲循环！来自 Porten 情绪音乐馆的推荐',
];

/// 解析 LRC 歌词：支持 [mm:ss.ss] 标准格式与 {"t":ms,"c":[{"tx":"..."}]}
/// JSON 行（逐行复刻 Web parseLrc：按时间排序、空文本剔除、解析失败忽略）。
List<LyricLine> parseLrc(String content) {
  final List<String> lines = content.split(RegExp(r'\r?\n'));
  final List<LyricLine> result = <LyricLine>[];
  for (final String raw in lines) {
    final String line = raw.trim();
    if (line.isEmpty) continue;
    // JSON 行：{"t":毫秒,"c":[{"tx":"..."}]}
    if (line.startsWith('{')) {
      try {
        final Object? obj = jsonDecode(line);
        if (obj is Map<String, dynamic>) {
          final double time = ((obj['t'] as num?) ?? 0) / 1000;
          final Object? segs = obj['c'];
          String text = '';
          if (segs is List) {
            for (final Object? seg in segs) {
              if (seg is Map && seg['tx'] is String) {
                text += seg['tx'] as String;
              }
            }
          }
          if (text.isNotEmpty) {
            result.add(LyricLine(time: time, text: text));
          }
        }
      } catch (_) {
        // 忽略解析失败的行（对齐 Web try/catch）
      }
      continue;
    }
    // 标准 [mm:ss.ss] 格式，可能一行多个时间戳
    final Iterable<RegExpMatch> matches =
        RegExp(r'\[(\d{1,2}):(\d{1,2}(?:\.\d+)?)\]').allMatches(line);
    if (matches.isEmpty) continue;
    final String text = line
        .replaceAll(RegExp(r'\[\d{1,2}:\d{1,2}(?:\.\d+)?\]'), '')
        .trim();
    for (final RegExpMatch m in matches) {
      final double time =
          int.parse(m.group(1)!) * 60 + double.parse(m.group(2)!);
      result.add(LyricLine(time: time, text: text));
    }
  }
  result.sort((LyricLine a, LyricLine b) => a.time.compareTo(b.time));
  return result;
}
