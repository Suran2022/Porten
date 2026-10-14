/*
 * 应用栏配置状态（Riverpod，对齐 Web 端 HomePage.tsx 的
 * showMusic + localStorage 持久化）。
 *
 * Web 端：APP_BAR_CONFIG_KEY = "porten_app_bar_config"，
 *   存 JSON {"showMusic": boolean}；PortenAppBarPage 开关 →
 *   setShowMusic + saveShowMusic；BottomNav 按 showMusic 追加
 *   「悦音乐」入口。
 * App 端：同一 key + JSON 结构，落到 SharedPreferences。
 */

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用栏配置状态。
class AppBarConfigState {
  const AppBarConfigState({this.showMusic = false});

  /// 底部栏是否展示「悦音乐」入口（默认关，对齐 Web 初始 false）。
  final bool showMusic;

  AppBarConfigState copyWith({bool? showMusic}) {
    return AppBarConfigState(showMusic: showMusic ?? this.showMusic);
  }
}

/// 应用栏配置控制器。
class AppBarConfigController extends Notifier<AppBarConfigState> {
  /// 与 Web 端 localStorage key 一致。
  static const String kPrefsKey = 'porten_app_bar_config';

  @override
  AppBarConfigState build() {
    _loadFromPrefs();
    return const AppBarConfigState();
  }

  /// 异步读取本地配置（对齐 Web loadShowMusic，异常时保持默认关）。
  Future<void> _loadFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(kPrefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final Object? parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        state = state.copyWith(showMusic: parsed['showMusic'] == true);
      }
    } on FormatException {
      // 损坏配置忽略，保持默认值（对齐 Web try/catch 容错）
    }
  }

  /// 切换「悦音乐」入口显隐并持久化（对齐 Web saveShowMusic）。
  Future<void> setShowMusic(bool show) async {
    state = state.copyWith(showMusic: show);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsKey, jsonEncode(<String, Object?>{'showMusic': show}));
  }
}

/// 全局应用栏配置 Provider。
final NotifierProvider<AppBarConfigController, AppBarConfigState>
    appBarConfigProvider =
    NotifierProvider<AppBarConfigController, AppBarConfigState>(
        AppBarConfigController.new);
