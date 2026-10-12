/*
 * 全局 Navigator Key（r20）。
 *
 * MaterialApp 挂载此 key，原生返回桥通过它查询 Flutter 导航栈是否可 pop，
 * 避免依赖 BuildContext 或 WidgetsBinding 内部结构。
 */

import 'package:flutter/widgets.dart';

/// 全局根导航栈 key。
final GlobalKey<NavigatorState> portenNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'porten_root_navigator');
