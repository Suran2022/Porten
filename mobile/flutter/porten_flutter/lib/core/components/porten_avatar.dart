/*
 * Porten 头像组件集。
 *
 * 还原 Web 端头像体系：
 *   - CampAvatar（营地）：无图 / 加载失败回退 gray-100 圆底 + UsersRound 图标；
 *   - MessageCard 无头像回退：gray-100 圆底 + Bot 图标；
 *   - PortenPartnerCard：无图回退 粉系渐变圆底 + 名称首字（白）；
 *   - ShareCard 作者头像：蓝粉渐变圆底 + 昵称首字（白）。
 *
 * 差异说明（Mock 离线策略）：Web 端会话头像来自 dicebear/pravatar 在线图源，
 * 移动端 Mock 模式下为保证离线可用与首帧确定性，好友头像统一采用
 * 「品牌渐变圆底 + 昵称首字」，与 ShareCard 的回退样式同源，不引入网络依赖。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';

/// 好友头像：优先本地资产图（圆形裁剪），为空回退品牌渐变圆底 + 昵称首字（白）。
class PortenFriendAvatar extends StatelessWidget {
  const PortenFriendAvatar(
      {super.key, required this.name, this.size = 48, this.asset});

  final String name;
  final double size;

  /// 本地头像资产路径（Mock 图片资源）。
  final String? asset;

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: PortenColor.gray100,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          asset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[PortenColor.brandBlue, PortenColor.brandPink],
        ),
      ),
      child: Text(
        name.characters.first,
        style: TextStyle(
          fontSize: size * 0.33,
          fontWeight: FontWeight.w500,
          color: PortenColor.white,
        ),
      ),
    );
  }
}

/// 营地头像：优先本地资产图，为空回退 gray-100 圆底 + UsersRound 图标（对齐 CampAvatar）。
class PortenCampAvatar extends StatelessWidget {
  const PortenCampAvatar({super.key, this.size = 48, this.asset});

  final double size;

  /// 本地营地头像资产路径（Mock 图片资源）。
  final String? asset;

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: PortenColor.gray100,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          asset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: PortenColor.gray100,
      ),
      child: Icon(
        Icons.groups_outlined,
        size: size * 0.45,
        color: PortenColor.gray400,
      ),
    );
  }
}

/// 伙伴头像：粉系渐变圆底 + 名称首字（对齐 PortenPartnerCard 回退态）。
class PortenPartnerAvatar extends StatelessWidget {
  const PortenPartnerAvatar({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String initial =
        name.trim().isEmpty ? 'P' : name.trim().characters.first;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            PortenColor.brandPink,
            PortenColor.brandPartnerPinkDeep,
          ],
        ),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.375,
          fontWeight: FontWeight.w500,
          color: PortenColor.white,
        ),
      ),
    );
  }
}

/// 作者头像：优先本地资产图，为空回退蓝粉渐变圆底 + 昵称首字（对齐 ShareCard）。
class PortenAuthorAvatar extends StatelessWidget {
  const PortenAuthorAvatar({super.key, required this.nickname, this.asset});

  final String nickname;

  /// 本地头像资产路径（Mock 图片资源）。
  final String? asset;

  @override
  Widget build(BuildContext context) {
    if (asset != null) {
      return Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: PortenColor.gray100,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          asset!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[PortenColor.brandBlue, PortenColor.brandPink],
        ),
      ),
      child: Text(
        nickname.characters.first,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: PortenColor.white,
        ),
      ),
    );
  }
}
