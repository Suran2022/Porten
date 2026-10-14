/*
 * 个人资料编辑状态（Riverpod，Mock 阶段本地可变，对齐 Web 端
 * authStore.updateUser 修改昵称/性别后的全量回显）。
 *
 * Web 端：EditNicknamePage.handleSave → updateNickname API →
 *   updateUser(mapProfileDataToAuthUser)；EditProfilePage
 *   .handleGenderChange → updateProfile({gender}) → updateUser。
 * App 端（无 HTTP 层）：修改即时写入 provider，资料页/编辑页
 *   同步回显；重启还原（与 AuthSession Mock 策略一致，不落盘）。
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gender_options.dart';
import '../profile_data.dart';

/// 资料编辑状态（初始值对齐 profile_data Mock）。
class ProfileEditState {
  const ProfileEditState({
    this.nickname = PortenProfileData.nickname,
    this.genderValue,
  });

  final String nickname;

  /// 性别 value（GenderValue 字符串）；null = 未设置。
  final String? genderValue;

  String get genderLabel => genderLabelOf(genderValue);

  ProfileEditState copyWith({String? nickname, String? genderValue}) {
    return ProfileEditState(
      nickname: nickname ?? this.nickname,
      genderValue: genderValue ?? this.genderValue,
    );
  }
}

/// 资料编辑控制器。
class ProfileEditController extends Notifier<ProfileEditState> {
  @override
  ProfileEditState build() {
    // 初始性别：Mock 资料卡展示「跨性别女生」
    return const ProfileEditState(genderValue: 'trans_female');
  }

  /// 修改昵称（对齐 Web updateNickname 成功后的本地更新）。
  void setNickname(String nickname) {
    state = state.copyWith(nickname: nickname);
  }

  /// 设置性别（对齐 Web updateProfile({gender})）。
  void setGender(String value) {
    state = state.copyWith(genderValue: value);
  }
}

/// 全局资料编辑 Provider。
final NotifierProvider<ProfileEditController, ProfileEditState>
    profileEditProvider =
    NotifierProvider<ProfileEditController, ProfileEditState>(
        ProfileEditController.new);
