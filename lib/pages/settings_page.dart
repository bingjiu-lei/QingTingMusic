import 'package:flutter/material.dart';

import '../services/api_endpoint_service.dart';
import '../services/cache_management_service.dart';
import '../theme/app_theme.dart';
import '../widgets/page_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onEndpointChanged});

  final VoidCallback? onEndpointChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _service = ApiEndpointService();
  final _cacheService = CacheManagementService();
  final _controller = TextEditingController();
  bool _saved = false;
  bool _saving = false;
  bool _cacheBusy = false;
  String? _errorText;
  String _activeEndpoint = '';
  int _cacheLimitBytes = CacheManagementService.defaultLimitBytes;
  int _cacheSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _service.load().then((value) {
      if (!mounted) return;
      _controller.text = value;
      _activeEndpoint = value;
      setState(() {});
    });
    _loadCacheState();
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
      widget.onEndpointChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _errorText = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadCacheState() async {
    final limit = await _cacheService.loadLimitBytes();
    final size = await _cacheService.cacheSizeBytes();
    if (!mounted) return;
    setState(() {
      _cacheLimitBytes = limit;
      _cacheSizeBytes = size;
    });
  }

  Future<void> _changeCacheLimit(int? value) async {
    if (value == null) return;
    setState(() {
      _cacheBusy = true;
      _cacheLimitBytes = value;
    });
    await _cacheService.saveLimitBytes(value);
    await _loadCacheState();
    if (mounted) setState(() => _cacheBusy = false);
  }

  Future<void> _clearCache() async {
    setState(() => _cacheBusy = true);
    await _cacheService.clearCache();
    await _loadCacheState();
    if (mounted) setState(() => _cacheBusy = false);
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
                  '留空时直接请求官方接口；填写后使用这个域名下的服务器接口。',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText:
                              '留空使用官方接口，或填写 https://music-api.example.com',
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
                          ? '当前模式：官方接口'
                          : '当前模式：自定义后端 $_activeEndpoint'),
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
                _CacheSection(
                  sizeText: _formatBytes(_cacheSizeBytes),
                  selectedLimit: _cacheLimitBytes,
                  busy: _cacheBusy,
                  onLimitChanged: _changeCacheLimit,
                  onClear: _clearCache,
                ),
                const Divider(height: 28),
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

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

class _CacheSection extends StatelessWidget {
  const _CacheSection({
    required this.sizeText,
    required this.selectedLimit,
    required this.busy,
    required this.onLimitChanged,
    required this.onClear,
  });

  final String sizeText;
  final int selectedLimit;
  final bool busy;
  final ValueChanged<int?> onLimitChanged;
  final VoidCallback onClear;

  static const _limits = <int>[
    512 * 1024 * 1024,
    1024 * 1024 * 1024,
    2 * 1024 * 1024 * 1024,
    5 * 1024 * 1024 * 1024,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.cleaning_services_rounded,
          color: AppColors.primary,
          size: 21,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '缓存管理',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '缓存用于提升加载与播放速度，超过上限会自动清理较早内容。',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CacheInfo(label: '当前占用', value: sizeText),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.page,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _limits.contains(selectedLimit)
                            ? selectedLimit
                            : CacheManagementService.defaultLimitBytes,
                        borderRadius: BorderRadius.circular(8),
                        dropdownColor: AppColors.surface,
                        iconEnabledColor: AppColors.muted,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        items: _limits
                            .map(
                              (value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text('上限 ${_limitLabel(value)}'),
                              ),
                            )
                            .toList(),
                        onChanged: busy ? null : onLimitChanged,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : onClear,
                    child: Text(busy ? '处理中' : '清理缓存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _limitLabel(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024 / 1024).toInt()} GB';
    }
    return '${(bytes / 1024 / 1024).toInt()} MB';
  }
}

class _CacheInfo extends StatelessWidget {
  const _CacheInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.selected.withValues(
          alpha: AppColors.isDark ? 0.55 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 13,
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
