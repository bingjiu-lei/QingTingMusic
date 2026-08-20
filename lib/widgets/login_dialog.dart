import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _mobileController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!widget.controller.isLoggedIn) widget.controller.startQrLogin();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        elevation: 0,
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF161B22).withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.border,
              width: 1,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, -2),
                    ),
                  ]
                : AppShadows.popover,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            child: Stack(
              children: [
                Positioned(
                  top: -60,
                  right: -40,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(
                            alpha: isDark ? 0.10 : 0.06,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Header(onClose: () => Navigator.of(context).pop()),
                      const SizedBox(height: 18),
                      _content(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final controller = widget.controller;
    if (controller.isLoggedIn) return _loggedIn(controller);

    return Column(
      children: [
        _MethodTabs(
          method: controller.method,
          onQr: controller.startQrLogin,
          onSms: controller.showSmsLogin,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 390,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: Align(
              key: ValueKey(
                controller.method == LoginMethod.sms ? 'sms' : 'qr',
              ),
              alignment: Alignment.topCenter,
              child: controller.method == LoginMethod.sms
                  ? _smsLogin(controller)
                  : _qrLogin(
                      title: '扫码登录',
                      subtitle: '使用酷狗概念版扫码',
                      imageDataUrl: controller.qrImageDataUrl,
                      qrText: controller.qrText,
                      status: _qrStatusText(controller),
                      helper: '请使用移动端扫描二维码，并在手机上确认。',
                      onRefresh: controller.startQrLogin,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loggedIn(AuthController controller) {
    return Column(
      children: [
        Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 48),
        const SizedBox(height: 12),
        Text(
          controller.session.displayName,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '账号已连接，可以同步音乐库并播放在线歌曲。',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        OutlinedButton(
          onPressed: () async {
            await controller.logout();
            if (mounted) Navigator.of(context).pop();
          },
          child: const Text('退出登录'),
        ),
      ],
    );
  }

  Widget _qrLogin({
    required String title,
    required String subtitle,
    required String? imageDataUrl,
    required String? qrText,
    required String status,
    required String helper,
    required VoidCallback onRefresh,
  }) {
    final controller = widget.controller;
    final image = _decodeImage(imageDataUrl);
    final showError =
        controller.state == AuthState.error ||
        controller.state == AuthState.expired;
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 18),
        Container(
          width: 206,
          height: 206,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: image == null
              ? qrText == null || qrText.isEmpty
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : QrImageView(
                        data: qrText,
                        size: 178,
                        backgroundColor: Colors.white,
                      )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    image,
                    width: 178,
                    height: 178,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
        ),
        const SizedBox(height: 14),
        Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: showError ? AppColors.danger : AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
        if (showError) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重新获取二维码'),
          ),
        ],
      ],
    );
  }

  Widget _smsLogin(AuthController controller) {
    final busy =
        controller.state == AuthState.sendingSms ||
        controller.state == AuthState.smsLoggingIn;
    return Column(
      key: const ValueKey('sms'),
      children: [
        Text(
          '验证码登录',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '无需密码，快捷安全',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        _LoginInput(
          controller: _mobileController,
          hintText: '手机号码',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _LoginInput(
                controller: _codeController,
                hintText: '验证码',
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _submitSms(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: busy || controller.smsCountdown > 0
                    ? null
                    : () => controller.sendSmsCode(_mobileController.text),
                child: Text(
                  controller.smsCountdown > 0
                      ? '${controller.smsCountdown}s'
                      : '获取验证码',
                ),
              ),
            ),
          ],
        ),
        if (controller.errorText?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              controller.errorText!,
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: busy ? null : _submitSms,
            child: Text(
              controller.state == AuthState.smsLoggingIn ? '正在登录' : '立即登录',
            ),
          ),
        ),
      ],
    );
  }

  void _submitSms() {
    widget.controller.loginBySms(_mobileController.text, _codeController.text);
  }

  String _qrStatusText(AuthController controller) {
    return switch (controller.state) {
      AuthState.initializing => '正在初始化登录服务',
      AuthState.loadingQr => '正在生成二维码',
      AuthState.waitingScan =>
        controller.lastQrStatus == null ? '等待扫码' : '等待扫码，桌面端正在同步状态',
      AuthState.waitingConfirm => '已扫码，请在手机上确认',
      AuthState.expired => '二维码已过期',
      AuthState.error => controller.errorText ?? '登录服务暂时不可用',
      AuthState.loggedIn => '登录成功',
      _ => '等待扫码',
    };
  }

  Uint8List? _decodeImage(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    try {
      final commaIndex = dataUrl.indexOf(',');
      return base64Decode(
        commaIndex >= 0 ? dataUrl.substring(commaIndex + 1) : dataUrl,
      );
    } catch (_) {
      return null;
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '登录晴听音乐',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: '关闭',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _MethodTabs extends StatelessWidget {
  const _MethodTabs({
    required this.method,
    required this.onQr,
    required this.onSms,
  });

  final LoginMethod method;
  final VoidCallback onQr;
  final VoidCallback onSms;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _MethodTab(
            icon: Icons.qr_code_rounded,
            label: '扫码',
            selected: method == LoginMethod.qrcode,
            onTap: onQr,
          ),
          _MethodTab(
            icon: Icons.smartphone_rounded,
            label: '手机',
            selected: method == LoginMethod.sms,
            onTap: onSms,
          ),
        ],
      ),
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: AppColors.isDark ? 0.18 : 0.06,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.text : AppColors.muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginInput extends StatelessWidget {
  const _LoginInput({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        style: TextStyle(color: AppColors.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: AppColors.faint, fontSize: 14),
          filled: true,
          fillColor: AppColors.surfaceMuted,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}
