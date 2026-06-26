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
  @override
  void initState() {
    super.initState();
    if (!widget.controller.isLoggedIn) widget.controller.startQrLogin();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 390,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _content(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final controller = widget.controller;
    if (controller.isLoggedIn) {
      return Column(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 48),
          const SizedBox(height: 12),
          Text(
            controller.session.displayName,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '账号已连接，可以搜索和播放在线歌曲。',
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

    final image = _decodeImage(controller.qrImageDataUrl);
    final qrText = controller.qrText;
    return Column(
      children: [
        Container(
          width: 220,
          height: 220,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.page,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: image == null
              ? qrText == null || qrText.isEmpty
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : QrImageView(
                        data: qrText,
                        size: 196,
                        backgroundColor: Colors.white,
                      )
              : Image.memory(
                  image,
                  width: 204,
                  height: 204,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
        ),
        const SizedBox(height: 16),
        Text(
          _statusText(controller),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: controller.state == AuthState.error
                ? AppColors.danger
                : AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '请使用移动端扫描二维码并在手机上确认。',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        if (controller.state == AuthState.expired ||
            controller.state == AuthState.error) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: controller.startQrLogin,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重新获取二维码'),
          ),
        ],
      ],
    );
  }

  String _statusText(AuthController controller) {
    return switch (controller.state) {
      AuthState.initializing => '正在初始化登录服务',
      AuthState.loadingQr => '正在生成二维码',
      AuthState.waitingScan =>
        controller.lastQrStatus == null ? '等待扫码' : '等待扫码，桌面端正在同步状态',
      AuthState.waitingConfirm => '已扫码，请在手机上确认',
      AuthState.expired => '二维码已过期',
      AuthState.error => controller.errorText ?? '登录服务暂时不可用',
      AuthState.loggedIn => '登录成功',
      AuthState.loggedOut => '等待扫码',
    };
  }

  Uint8List? _decodeImage(String? dataUrl) {
    if (dataUrl == null || dataUrl.isEmpty) return null;
    try {
      return base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }
}
