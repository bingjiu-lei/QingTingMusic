import 'package:flutter/material.dart';

import '../services/api_endpoint_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _service = ApiEndpointService();
  final _controller = TextEditingController();
  bool _saved = false;
  bool _saving = false;
  String? _errorText;
  String _activeEndpoint = '';

  @override
  void initState() {
    super.initState();
    _service.load().then((value) {
      if (!mounted) return;
      _controller.text = value;
      _activeEndpoint = value;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saved = false;
      _errorText = null;
    });
    try {
      await _service.save(_controller.text);
      final active = await _service.load();
      if (!mounted) return;
      setState(() {
        _activeEndpoint = active;
        _controller.text = active;
        _saved = true;
      });
    } catch (error) {
      if (mounted) setState(() => _errorText = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: '设置', subtitle: '调整晴听音乐的使用偏好'),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '后端 API',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '用于登录、搜索和在线播放。地址会保存在本机。',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'https://example.com',
                          prefixIcon: const Icon(Icons.dns_outlined, size: 20),
                          filled: true,
                          fillColor: AppColors.page,
                          border: const OutlineInputBorder(
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving
                            ? '检测中'
                            : _saved
                            ? '已保存'
                            : '保存',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  _errorText ??
                      (_activeEndpoint.isEmpty
                          ? '当前未配置后端，在线功能不可用'
                          : '当前生效：$_activeEndpoint'),
                  style: TextStyle(
                    color: _errorText == null
                        ? AppColors.muted
                        : AppColors.danger,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(height: 34),
                _SettingRow(
                  icon: Icons.high_quality_rounded,
                  title: '播放音质',
                  value: '标准音质',
                ),
                const Divider(height: 28),
                _SettingRow(
                  icon: Icons.info_outline_rounded,
                  title: '关于晴听音乐',
                  value: '1.0.0',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 21),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(value, style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ],
    );
  }
}
