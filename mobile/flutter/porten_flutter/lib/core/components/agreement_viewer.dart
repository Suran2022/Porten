/*
 * 协议全文查看器（对齐 Web 端 AgreementViewer）。
 *
 * Web 端实现：底部弹出的全屏文档面板，顶部标题 + 关闭按钮，
 * 正文为协议条款静态文案；内容超出时滚动。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';

/// 协议全文底部面板。
class AgreementViewer extends StatelessWidget {
  const AgreementViewer({super.key, required this.title});

  final String title;

  static const Map<String, List<String>> _bodies = <String, List<String>>{
    '用户协议': <String>[
      '欢迎使用 Porten。Porten 是一个面向跨性别群体的匿名互助社区，'
          '我们致力于为你提供安全、友善的交流环境。',
      '1. 你承诺年满 18 周岁，且具备完全民事行为能力；未成年人不得使用本平台。',
      '2. 你在使用过程中应遵守所在地区法律法规，不得发布违法、色情、暴力、'
          '歧视性或侵犯他人权益的内容。',
      '3. 平台内容（包括但不限于行程、帖子、私信）仅用于社区交流，'
          '不得用于商业转售或其他未经授权的用途。',
      '4. 我们有权对违反本协议的账号采取警告、限流、封禁等措施。',
      '5. 本协议的更新会通过站内通知告知；继续使用即视为接受更新后的协议。',
    ],
    '跨性别资源': <String>[
      'Porten 收录的跨性别相关资源（医疗、心理、法律援助等）仅供信息参考，'
          '不构成任何专业建议。',
      '1. 资源信息由社区成员与运营团队共同维护，可能存在滞后，'
          '使用前请自行核实。',
      '2. 平台不对第三方服务的结果承担责任；与第三方产生的纠纷请直接与对方协商。',
      '3. 如发现资源信息有误或已失效，欢迎通过站内反馈渠道告知我们。',
    ],
    '信息收集': <String>[
      '为了提供核心服务，我们会收集以下信息：',
      '1. 账号信息：邮箱/手机号、加密后的登录凭证；',
      '2. 设备信息：设备型号、操作系统版本，用于崩溃排查与安全防护；',
      '3. 使用数据：功能访问记录，用于改进产品体验。',
      '我们不会向任何第三方出售你的个人信息；数据共享仅发生在'
          '履行服务所必需的范围（如短信验证码服务商）。',
      '你可以随时通过「设置 - 数据与隐私」导出或删除你的个人数据。',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final List<String> paragraphs =
        _bodies[title] ?? <String>['协议内容暂未收录，请联系客服获取完整文本。'];
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: PortenColor.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PortenColor.gray300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: PortenTypography.lg.copyWith(
                          color: PortenColor.gray900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close,
                          size: 20, color: PortenColor.gray400),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: PortenColor.divider),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  itemCount: paragraphs.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        paragraphs[index],
                        style: PortenTypography.sm.copyWith(
                          color: PortenColor.gray600,
                          height: 1.7,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
