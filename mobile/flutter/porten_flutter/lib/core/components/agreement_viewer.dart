/*
 * 协议全文查看器（100% 对齐 Web 端 AgreementViewer.tsx）。
 *
 * Web 端实现：
 *   - 全屏白页从右侧滑入（translateX 100% → 0，300ms cubic-bezier(0.25,0.1,0.25,1)）；
 *   - 顶栏：BackIcon（w-7 h-7）+ 居中标题（text-lg font-medium）+ 右侧「下载」
 *     （text-sm text-gray-600，App 端 Mock 阶段仅 toast 提示）；
 *   - 内容区 max-w-md px-5 py-6：中央 porten-gradient Logo（text-4xl），
 *     修订/生效时间行（text-xs gray-500），章节（text-base font-semibold）
 *     与段落（text-sm text-gray-700 leading-relaxed），段落内《…》链接
 *     #F5A9B8 下划线、可互跳其他协议；
 *   - 底部联系方式区 + 「反馈」「发送至邮箱」。
 */

import 'package:flutter/material.dart';

import '../design/porten_colors.dart';
import '../design/porten_typography.dart';
import 'gradient_logo.dart';
import 'porten_icons.dart';
import 'porten_toast.dart';
import '../data/agreements.dart';

/// 协议全文查看页。
class AgreementViewer extends StatelessWidget {
  const AgreementViewer({super.key, required this.agreementId});

  final String agreementId;

  /// 全屏右滑打开。
  static void open(BuildContext context, String agreementId) {
    if (getAgreementById(agreementId) == null) return; // 防御：未知 id 不跳转
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => AgreementViewer(agreementId: agreementId),
        transitionsBuilder: (_, animation, _, Widget child) {
          final CurvedAnimation curved = CurvedAnimation(
            parent: animation,
            curve: const Cubic(0.25, 0.1, 0.25, 1),
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  /// 段落内《…》链接 → 协议 id（对齐 Web 端 titleToIdMap）。
  static const Map<String, String> _titleToId = <String, String>{
    '用户协议': 'user',
    '跨性别资源': 'trans',
    '跨性别用户权益保护与社区资源公约': 'trans',
    '信息收集': 'privacy',
    '信息收集与隐私保护政策': 'privacy',
  };

  /// 拆分段落为 [普通文本 | 链接(协议id)] 片段（对齐 parseParagraphWithLinks）。
  static List<(String, String?)> parseParagraph(String text) {
    final List<(String, String?)> parts = <(String, String?)>[];
    final RegExp regex = RegExp(r'(《[^《》]+》)');
    int last = 0;
    for (final RegExpMatch m in regex.allMatches(text)) {
      if (m.start > last) parts.add((text.substring(last, m.start), null));
      final String raw = m.group(0)!;
      final String inner = raw.substring(1, raw.length - 1);
      final String? id = _titleToId[inner] ?? _titleToId[raw];
      parts.add((raw, id));
      last = m.end;
    }
    if (last < text.length) parts.add((text.substring(last), null));
    return parts;
  }

  void _openLink(BuildContext context, String id) {
    if (id == agreementId) return; // 已在当前协议内，不重复压栈
    open(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final AgreementDocument agreement = getAgreementById(agreementId)!;

    return Scaffold(
      backgroundColor: PortenColor.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            // 顶栏：border-b border-gray-100
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: <Widget>[
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: PortenBackIcon(size: 28),
                  ),
                  Expanded(
                    child: Text(
                      agreement.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PortenTypography.lg.copyWith(
                        color: PortenColor.gray900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => PortenToast.show('下载功能建设中（Mock 阶段）'),
                    child: Text(
                      '下载',
                      style: PortenTypography.sm
                          .copyWith(color: PortenColor.gray600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 中央 Logo（text-4xl = 36）
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 24),
                        child: GradientLogo(fontSize: 36),
                      ),
                    ),
                    // 修订/生效时间行
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            '修订时间：${agreement.revisionTime}',
                            style: PortenTypography.xs
                                .copyWith(color: PortenColor.gray500),
                          ),
                          Text(
                            '生效时间：${agreement.effectiveTime}',
                            style: PortenTypography.xs
                                .copyWith(color: PortenColor.gray500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 章节与段落
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final AgreementSection section
                              in agreement.sections) ...<Widget>[
                            if (section.title != null) ...<Widget>[
                              Text(
                                section.title!,
                                style: PortenTypography.base.copyWith(
                                  color: PortenColor.gray900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            for (final String paragraph
                                in section.paragraphs) ...<Widget>[
                              _Paragraph(
                                text: paragraph,
                                onOpenLink: (String id) =>
                                    _openLink(context, id),
                              ),
                              const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 8), // space-y-5 视觉近似
                          ],
                        ],
                      ),
                    ),
                    _ContactFooter(),
                    SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 段落：text-sm text-gray-700 leading-relaxed，内嵌《…》链接。
class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text, required this.onOpenLink});

  final String text;
  final ValueChanged<String> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final List<(String, String?)> parts = AgreementViewer.parseParagraph(text);
    return Text.rich(
      TextSpan(
        style: PortenTypography.sm.copyWith(
          color: PortenColor.gray700,
          height: 1.625, // leading-relaxed
        ),
        children: <InlineSpan>[
          for (final (String, String?) part in parts)
            if (part.$2 == null)
              TextSpan(text: part.$1)
            else
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () => onOpenLink(part.$2!),
                  child: Text(
                    part.$1,
                    style: PortenTypography.sm.copyWith(
                      color: const Color(0xFFF5A9B8),
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFFF5A9B8),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// 底部联系方式区（对齐 Web 端 footer）。
class _ContactFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        PortenTypography.sm.copyWith(color: PortenColor.gray600);
    const Color linkColor = Color(0xFFF5A9B8);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      padding: const EdgeInsets.only(top: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Porten 通信平台',
              style: base.copyWith(
                  color: PortenColor.gray900, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('访问地址：your-domain.com', style: base),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: base,
              children: <InlineSpan>[
                const TextSpan(text: '团队联系邮箱：'),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => PortenToast.show('反馈功能建设中（Mock 阶段）'),
                    child: Text(
                      'your_contact@email.com',
                      style: base.copyWith(
                        color: linkColor,
                        decoration: TextDecoration.underline,
                        decorationColor: linkColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('联系 QQ：your_qq_number', style: base),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: () => PortenToast.show('反馈功能建设中（Mock 阶段）'),
                child: Text('反馈',
                    style: base.copyWith(
                        color: linkColor,
                        decoration: TextDecoration.underline,
                        decorationColor: linkColor)),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => PortenToast.show('发送至邮箱功能建设中（Mock 阶段）'),
                child: Text('发送至邮箱',
                    style: base.copyWith(
                        color: linkColor,
                        decoration: TextDecoration.underline,
                        decorationColor: linkColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
