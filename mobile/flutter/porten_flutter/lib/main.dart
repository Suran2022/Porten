/*
 * Flutter 入口（对齐 bootstrap.dart 的唯一入口约定）。
 *
 * 原生壳通过 FlutterEngine 缓存预热（DartEntrypoint.createDefault）执行本文件；
 * 启动编排（ProviderScope + PortenApp）全部收敛在 bootstrap.dart，本文件保持极简。
 */

import 'bootstrap.dart';

void main() => runPortenFlutterApp();
