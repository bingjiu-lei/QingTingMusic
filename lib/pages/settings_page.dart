import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/playback_quality_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/update_controller.dart';
import '../models/app_update.dart';
import '../services/api_endpoint_service.dart';
import '../services/app_storage_service.dart';
import '../services/cache_management_service.dart';
import '../services/developer_mode_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_scrollbar.dart';
import '../widgets/page_header.dart';
import '../widgets/playback_quality_menu.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.updateController,
    required this.onCheckUpdates,
    required this.closeToTray,
    required this.onCloseToTrayChanged,
    required this.sidebarExpanded,
    required this.onSidebarExpandedChanged,
    required this.playbackQualityController,
    required this.themeController,
    this.onEndpointChanged,
    this.onDeveloperModeChanged,
    this.onNotice,
  });

  final UpdateController updateController;
  final VoidCallback onCheckUpdates;
  final bool closeToTray;
  final ValueChanged<bool> onCloseToTrayChanged;
  final bool sidebarExpanded;
  final ValueChanged<bool> onSidebarExpandedChanged;
  final PlaybackQualityController playbackQualityController;
  final ThemeController themeController;
  final VoidCallback? onEndpointChanged;
  final ValueChanged<bool>? onDeveloperModeChanged;
  final ValueChanged<String>? onNotice;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _projectUrl = 'https://github.com/bingjiu-lei/QingTingMusic';

  final _service = ApiEndpointService();
  final _cacheService = CacheManagementService();
  final _developerService = DeveloperModeService();
  final _controller = TextEditingController();
  final _githubProxyController = TextEditingController();
  bool _saved = false;
  bool _proxySaved = false;
  bool _saving = false;
  bool _savingProxy = false;
  bool _cacheBusy = false;
  bool _developerEnabled = false;
  String? _errorText;
  String? _proxyErrorText;
  String _activeEndpoint = '';
  int _cacheLimitBytes = CacheManagementService.defaultLimitBytes;
  int _cacheSizeBytes = 0;
  int _versionTapCount = 0;
  Timer? _versionTapTimer;

  @override
  void initState() {
    super.initState();
    _service.load().then((value) {
      if (!mounted) return;
      _controller.text = value;
      _activeEndpoint = value;
      setState(() {});
    });
    _developerService.loadEnabled().then((enabled) {
      if (!mounted) return;
      setState(() => _developerEnabled = enabled);
    });
    _githubProxyController.text = widget.updateController.githubProxyUrl;
    _loadCacheState();
    widget.updateController.addListener(_refreshUpdateState);
  }

  @override
  void dispose() {
    _versionTapTimer?.cancel();
    widget.updateController.removeListener(_refreshUpdateState);
    _controller.dispose();
    _githubProxyController.dispose();
    super.dispose();
  }

  void _refreshUpdateState() {
    if (!mounted) return;
    setState(() {});
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

  Future<void> _saveGithubProxy() async {
    setState(() {
      _savingProxy = true;
      _proxySaved = false;
      _proxyErrorText = null;
    });
    try {
      await widget.updateController.setGithubProxyUrl(
        _githubProxyController.text,
      );
      if (!mounted) return;
      setState(() {
        _githubProxyController.text = widget.updateController.githubProxyUrl;
        _proxySaved = true;
      });
    } catch (error) {
      if (mounted) setState(() => _proxyErrorText = error.toString());
    } finally {
      if (mounted) setState(() => _savingProxy = false);
    }
  }

  Future<void> _openProjectHome() async {
    try {
      await Process.start('rundll32', [
        'url.dll,FileProtocolHandler',
        _projectUrl,
      ], mode: ProcessStartMode.detached);
    } catch (_) {
      if (!mounted) return;
      await Clipboard.setData(const ClipboardData(text: _projectUrl));
      if (!mounted) return;
      _showSnack('项目地址已复制');
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

  void _handleVersionTap() {
    _versionTapTimer?.cancel();
    _versionTapCount += 1;
    if (_versionTapCount >= 6) {
      _versionTapCount = 0;
      _developerEnabled ? _disableDeveloperMode() : _showDeveloperDialog();
      return;
    }
    _versionTapTimer = Timer(const Duration(seconds: 2), () {
      _versionTapCount = 0;
    });
  }

  Future<void> _showDeveloperDialog() async {
    final passphraseController = TextEditingController();
    var errorText = '';
    final enabled = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              icon: Icons.vpn_key_rounded,
              title: '开发者模式',
              subtitle: '输入口令后会显示后端接口、更新代理和诊断日志等调试工具。',
              maxWidth: 400,
              content: AppDialogTextField(
                controller: passphraseController,
                obscureText: true,
                autofocus: true,
                hintText: '开发者口令',
                errorText: errorText.isEmpty ? null : errorText,
                prefixIcon: Icons.key_rounded,
                onSubmitted: (_) {
                  _submitDeveloperPassphrase(
                    dialogContext,
                    setDialogState,
                    passphraseController.text,
                    (value) => errorText = value,
                  );
                },
              ),
              actions: [
                AppDialogButton.ghost(
                  label: '取消',
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                const SizedBox(width: 8),
                AppDialogButton.primary(
                  label: '开启',
                  onPressed: () {
                    _submitDeveloperPassphrase(
                      dialogContext,
                      setDialogState,
                      passphraseController.text,
                      (value) => errorText = value,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
    passphraseController.dispose();
    if (enabled != true || !mounted) return;
    await _developerService.saveEnabled(true);
    if (!mounted) return;
    setState(() => _developerEnabled = true);
    widget.onDeveloperModeChanged?.call(true);
    _showSnack('开发者模式已开启');
  }

  void _submitDeveloperPassphrase(
    BuildContext dialogContext,
    StateSetter setDialogState,
    String passphrase,
    ValueChanged<String> setError,
  ) {
    if (_developerService.verifyPassphrase(passphrase)) {
      Navigator.of(dialogContext).pop(true);
      return;
    }
    setDialogState(() => setError('口令不正确'));
  }

  Future<void> _disableDeveloperMode() async {
    await _developerService.saveEnabled(false);
    if (!mounted) return;
    setState(() => _developerEnabled = false);
    widget.onDeveloperModeChanged?.call(false);
    _showSnack('开发者模式已关闭');
  }

  Future<void> _copyDiagnosticInfo() async {
    final logFile = AppStorageService.file('playback.log');
    final info = [
      'QingTingMusic diagnostics',
      'version: ${widget.updateController.currentVersion}',
      'dataDirectory: ${AppStorageService.dataDirectory.path}',
      'apiMode: ${_activeEndpoint.isEmpty ? 'official' : 'custom'}',
      'cacheLimit: $_cacheLimitBytes',
      'cacheSize: $_cacheSizeBytes',
      'autoUpdateCheck: ${widget.updateController.autoCheck}',
      'githubProxy: ${widget.updateController.githubProxyUrl.isEmpty ? 'empty' : 'configured'}',
      'playbackLog: ${await logFile.exists() ? 'exists' : 'missing'}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: info));
    if (mounted) _showSnack('诊断信息已复制');
  }

  Future<void> _showPlaybackLog() async {
    final file = AppStorageService.file('playback.log');
    var content = '暂无播放日志。';
    if (await file.exists()) {
      final value = await file.readAsString();
      content = value.length > 8000
          ? value.substring(value.length - 8000)
          : value;
      if (content.trim().isEmpty) content = '暂无播放日志。';
    }
    if (!mounted) return;
    _showLongTextDialog(title: '播放日志', content: content);
  }

  void _showLegalDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AppDialog(
          maxWidth: 620,
          icon: Icons.gavel_rounded,
          title: '免责声明与版权声明',
          showCloseButton: true,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegalItem(
                    title: '项目定位',
                    content:
                        '本项目是基于公开接口与用户授权数据开发的第三方音乐客户端，仅用于技术学习、研究和个人使用，不涉及任何商业行为。',
                  ),
                  _LegalItem(
                    title: '数据来源',
                    content: '音乐数据来自相关平台公开或授权接口。本项目不拥有音乐版权，不主动存储、传播或分发任何音频内容。',
                  ),
                  _LegalItem(
                    title: '缓存说明',
                    content: '本地缓存仅用于改善加载与播放体验，可在设置中清理。用户应遵守当地法律法规及相关平台使用条款。',
                  ),
                  _LegalItem(
                    title: '版权尊重',
                    content: '音乐创作不易，请支持正版。若长期使用相关服务，建议通过官方渠道购买会员或数字专辑。',
                  ),
                  _LegalItem(
                    title: '责任说明',
                    content: '因使用本项目产生的账号风险、接口不可用、数据丢失、设备异常或其他间接损失，开发者不承担责任。',
                  ),
                  _LegalItem(
                    title: '争议处理',
                    content: '如权利方认为本项目影响其合法权益，可通过项目仓库联系处理，我们会积极配合调整。',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            AppDialogButton.primary(
              label: '我知道了',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showLongTextDialog({required String title, required String content}) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AppDialog(
          maxWidth: 680,
          icon: Icons.article_outlined,
          title: title,
          showCloseButton: true,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ),
          ),
          actions: [
            AppDialogButton.ghost(
              label: '复制',
              icon: Icons.copy_rounded,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.of(context).pop();
                _showSnack('内容已复制');
              },
            ),
            const SizedBox(width: 8),
            AppDialogButton.primary(
              label: '关闭',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message) {
    final onNotice = widget.onNotice;
    if (onNotice != null) {
      onNotice(message);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showAccentPicker() async {
    var color = HSVColor.fromColor(widget.themeController.accentColor);
    final selected = await showDialog<Color>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          maxWidth: 400,
          icon: Icons.palette_outlined,
          title: '自定义主题色',
          subtitle: '拖动滑块调整界面主色调',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.fast,
                height: 64,
                decoration: BoxDecoration(
                  color: color.toColor(),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: color.toColor().withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  '晴听音乐',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _ColorSlider(
                label: '色相',
                value: color.hue,
                max: 360,
                gradient: const LinearGradient(
                  colors: [
                    Colors.red,
                    Colors.yellow,
                    Colors.green,
                    Colors.cyan,
                    Colors.blue,
                    Colors.purple,
                    Colors.red,
                  ],
                ),
                onChanged: (value) =>
                    setDialogState(() => color = color.withHue(value)),
              ),
              _ColorSlider(
                label: '浓度',
                value: color.saturation,
                max: 1,
                onChanged: (value) =>
                    setDialogState(() => color = color.withSaturation(value)),
              ),
              _ColorSlider(
                label: '明度',
                value: color.value,
                max: 1,
                onChanged: (value) =>
                    setDialogState(() => color = color.withValue(value)),
              ),
            ],
          ),
          actions: [
            AppDialogButton.ghost(
              label: '取消',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            const SizedBox(width: 8),
            AppDialogButton.primary(
              label: '应用',
              onPressed: () => Navigator.of(dialogContext).pop(color.toColor()),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await widget.themeController.setCoverAccentEnabled(false);
      await widget.themeController.setAccentColor(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(title: '设置', subtitle: '调整晴听音乐的使用偏好'),
            const SizedBox(height: 22),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(
                    alpha: AppColors.isDark ? 0.78 : 0.86,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.isDark ? null : AppShadows.soft,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: AppScrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AppearanceSection(
                            controller: widget.themeController,
                            onCustomColor: _showAccentPicker,
                          ),
                          Divider(
                            height: 32,
                            color: AppColors.divider.withValues(alpha: 0.72),
                          ),
                          _CacheSection(
                            sizeText: _formatBytes(_cacheSizeBytes),
                            selectedLimit: _cacheLimitBytes,
                            busy: _cacheBusy,
                            onLimitChanged: _changeCacheLimit,
                            onClear: _clearCache,
                          ),
                          Divider(
                            height: 32,
                            color: AppColors.divider.withValues(alpha: 0.72),
                          ),
                          _PlaybackQualitySection(
                            controller: widget.playbackQualityController,
                          ),
                          Divider(
                            height: 32,
                            color: AppColors.divider.withValues(alpha: 0.72),
                          ),
                          _SettingSwitchRow(
                            icon: Icons.web_asset_rounded,
                            title: '关闭后隐藏到托盘',
                            subtitle: '关闭窗口时继续后台播放，可在托盘退出应用',
                            value: widget.closeToTray,
                            onChanged: widget.onCloseToTrayChanged,
                          ),
                          Divider(
                            height: 32,
                            color: AppColors.divider.withValues(alpha: 0.72),
                          ),
                          _SettingSwitchRow(
                            icon: Icons.view_sidebar_rounded,
                            title: '展开侧边栏',
                            subtitle: '点击侧边分割线，即可切换侧边栏的展开状态',
                            value: widget.sidebarExpanded,
                            onChanged: widget.onSidebarExpandedChanged,
                          ),
                          Divider(
                            height: 32,
                            color: AppColors.divider.withValues(alpha: 0.72),
                          ),
                          _UpdateSection(
                            controller: widget.updateController,
                            onCheckUpdates: widget.onCheckUpdates,
                            onVersionTap: _handleVersionTap,
                            onProjectTap: _openProjectHome,
                            onLegalTap: _showLegalDialog,
                          ),
                          if (_developerEnabled) ...[
                            Divider(
                              height: 32,
                              color: AppColors.divider.withValues(alpha: 0.72),
                            ),
                            _DeveloperSection(
                              apiController: _controller,
                              githubProxyController: _githubProxyController,
                              activeEndpoint: _activeEndpoint,
                              endpointErrorText: _errorText,
                              proxyErrorText: _proxyErrorText,
                              endpointSaved: _saved,
                              proxySaved: _proxySaved,
                              savingEndpoint: _saving,
                              savingProxy: _savingProxy,
                              onSaveEndpoint: _save,
                              onSaveGithubProxy: _saveGithubProxy,
                              onCopyDiagnostics: _copyDiagnosticInfo,
                              onShowPlaybackLog: _showPlaybackLog,
                              onDisable: _disableDeveloperMode,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(
              alpha: AppColors.isDark ? 0.14 : 0.08,
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.controller,
    required this.onCustomColor,
  });

  static const colors = [
    Color(0xFF2788F5),
    Color(0xFF7C5CF5),
    Color(0xFFEC6A8F),
    Color(0xFFF0783E),
    Color(0xFF20A37A),
  ];

  final ThemeController controller;
  final VoidCallback onCustomColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionHeader(
        icon: Icons.palette_outlined,
        title: '外观',
        subtitle: '主题色会影响选中状态、按钮和页面氛围，品牌图标仍保持原色。',
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.only(left: 52),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ThemeModeSwitcher(
              isDark: controller.isDark,
              onChanged: controller.setDarkMode,
            ),
            const SizedBox(width: 4),
            for (final color in colors) ...[
              _ThemeSwatch(
                color: color,
                selected:
                    !controller.coverAccentEnabled &&
                    controller.accentColor.toARGB32() == color.toARGB32(),
                onTap: () async {
                  await controller.setCoverAccentEnabled(false);
                  await controller.setAccentColor(color);
                },
              ),
            ],
            _CoverAccentButton(
              enabled: controller.coverAccentEnabled,
              onTap: () => controller.setCoverAccentEnabled(
                !controller.coverAccentEnabled,
              ),
            ),
            _SettingsButton(
              icon: Icons.colorize_rounded,
              label: '自定义',
              onPressed: onCustomColor,
            ),
            _SettingsButton.ghost(
              label: '恢复默认',
              onPressed: () async {
                await controller.setCoverAccentEnabled(false);
                await controller.resetAccentColor();
              },
            ),
          ],
        ),
      ),
    ],
  );
}

class _ThemeModeSwitcher extends StatelessWidget {
  const _ThemeModeSwitcher({required this.isDark, required this.onChanged});

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem(
            label: '浅色',
            icon: Icons.light_mode_rounded,
            active: !isDark,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 2),
          _buildItem(
            label: '深色',
            icon: Icons.dark_mode_rounded,
            active: isDark,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: active && !AppColors.isDark
                ? [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: active ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.text : AppColors.muted,
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatefulWidget {
  const _ThemeSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ThemeSwatch> createState() => _ThemeSwatchState();
}

class _ThemeSwatchState extends State<_ThemeSwatch> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '使用此主题色',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovered ? 1.1 : 1.0,
            duration: AppMotion.fast,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.selected
                      ? (AppColors.isDark ? Colors.white : AppColors.text)
                      : Colors.white.withValues(alpha: 0.2),
                  width: widget.selected ? 2.5 : 1.5,
                ),
                boxShadow: widget.selected
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: widget.selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 17,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverAccentButton extends StatelessWidget {
  const _CoverAccentButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? '关闭随封面取色' : '主题色跟随当前歌曲封面',
      child: _SettingsButton(
        icon: enabled ? Icons.album_rounded : Icons.album_outlined,
        label: '封面取色',
        active: enabled,
        onPressed: onTap,
      ),
    );
  }
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.gradient,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 42,
        child: Text(label, style: TextStyle(color: AppColors.muted)),
      ),
      Expanded(
        child: Container(
          decoration: gradient == null
              ? null
              : BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(999),
                ),
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}

class _DeveloperSection extends StatelessWidget {
  const _DeveloperSection({
    required this.apiController,
    required this.githubProxyController,
    required this.activeEndpoint,
    required this.endpointErrorText,
    required this.proxyErrorText,
    required this.endpointSaved,
    required this.proxySaved,
    required this.savingEndpoint,
    required this.savingProxy,
    required this.onSaveEndpoint,
    required this.onSaveGithubProxy,
    required this.onCopyDiagnostics,
    required this.onShowPlaybackLog,
    required this.onDisable,
  });

  final TextEditingController apiController;
  final TextEditingController githubProxyController;
  final String activeEndpoint;
  final String? endpointErrorText;
  final String? proxyErrorText;
  final bool endpointSaved;
  final bool proxySaved;
  final bool savingEndpoint;
  final bool savingProxy;
  final VoidCallback onSaveEndpoint;
  final VoidCallback onSaveGithubProxy;
  final VoidCallback onCopyDiagnostics;
  final VoidCallback onShowPlaybackLog;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: AppColors.isDark ? 0.14 : 0.08,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Icon(
                Icons.code_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '开发者管理',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '调试接口、升级代理和运行日志。普通使用无需调整这些选项。',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            _SettingsButton.ghost(label: '关闭开发者模式', onPressed: onDisable),
          ],
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(left: 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DeveloperTextField(
                title: '后端 API',
                description: '留空时直接请求官方接口；填写后使用这个域名下的服务器接口。',
                controller: apiController,
                hintText: '留空使用官方接口，或填写 https://music-api.example.com',
                icon: Icons.dns_outlined,
                saving: savingEndpoint,
                saved: endpointSaved,
                onSave: onSaveEndpoint,
              ),
              const SizedBox(height: 8),
              Text(
                endpointErrorText ??
                    (activeEndpoint.isEmpty
                        ? '当前模式：官方接口'
                        : '当前模式：自定义后端 $activeEndpoint'),
                style: TextStyle(
                  color: endpointErrorText == null
                      ? AppColors.muted
                      : AppColors.danger,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              _DeveloperTextField(
                title: '更新代理',
                description: 'GitHub 连接较慢时可填写加速地址；留空时直接请求 GitHub。',
                controller: githubProxyController,
                hintText: '例如 https://gh-proxy.example.com/',
                icon: Icons.travel_explore_rounded,
                saving: savingProxy,
                saved: proxySaved,
                onSave: onSaveGithubProxy,
              ),
              const SizedBox(height: 8),
              Text(
                proxyErrorText ??
                    (githubProxyController.text.trim().isEmpty
                        ? '当前模式：直接检查更新'
                        : '当前模式：使用更新代理'),
                style: TextStyle(
                  color: proxyErrorText == null
                      ? AppColors.muted
                      : AppColors.danger,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SettingsButton(
                    icon: Icons.content_copy_rounded,
                    label: '复制诊断信息',
                    onPressed: onCopyDiagnostics,
                  ),
                  _SettingsButton(
                    icon: Icons.article_outlined,
                    label: '查看播放日志',
                    onPressed: onShowPlaybackLog,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeveloperTextField extends StatelessWidget {
  const _DeveloperTextField({
    required this.title,
    required this.description,
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.saving,
    required this.saved,
    required this.onSave,
  });

  final String title;
  final String description;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool saving;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: AppColors.muted.withValues(alpha: 0.65),
                      fontSize: 12.5,
                    ),
                    prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
                    filled: true,
                    fillColor: AppColors.page,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _SettingsButton.primary(
              label: saving
                  ? '保存中'
                  : saved
                  ? '已保存'
                  : '保存',
              loading: saving,
              onPressed: saving ? null : onSave,
            ),
          ],
        ),
      ],
    );
  }
}

class _UpdateSection extends StatelessWidget {
  const _UpdateSection({
    required this.controller,
    required this.onCheckUpdates,
    required this.onVersionTap,
    required this.onProjectTap,
    required this.onLegalTap,
  });

  final UpdateController controller;
  final VoidCallback onCheckUpdates;
  final VoidCallback onVersionTap;
  final VoidCallback onProjectTap;
  final VoidCallback onLegalTap;

  @override
  Widget build(BuildContext context) {
    final checking = controller.checkStatus == UpdateCheckStatus.checking;
    final version = controller.currentVersion.isEmpty
        ? '读取中'
        : 'v${controller.currentVersion}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: AppColors.isDark ? 0.14 : 0.08,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '关于晴听音乐',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _VersionBadge(version: version, onTap: onVersionTap),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '极简清爽的第三方桌面音乐客户端',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 52),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _AutoCheckChip(
                selected: controller.autoCheck,
                onChanged: controller.setAutoCheck,
              ),
              _SettingsButton(
                icon: Icons.system_update_alt_rounded,
                label: checking ? '检查中' : '检查更新',
                loading: checking,
                onPressed: checking ? null : onCheckUpdates,
              ),
              _SettingsButton(
                icon: Icons.open_in_new_rounded,
                label: '项目地址',
                onPressed: onProjectTap,
              ),
              _SettingsButton(
                icon: Icons.gavel_rounded,
                label: '声明',
                onPressed: onLegalTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VersionBadge extends StatefulWidget {
  const _VersionBadge({required this.version, required this.onTap});

  final String version;
  final VoidCallback onTap;

  @override
  State<_VersionBadge> createState() => _VersionBadgeState();
}

class _VersionBadgeState extends State<_VersionBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '连续点击可切换开发者模式',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.primary.withValues(
                      alpha: AppColors.isDark ? 0.22 : 0.14,
                    )
                  : AppColors.primary.withValues(
                      alpha: AppColors.isDark ? 0.14 : 0.08,
                    ),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColors.primary.withValues(
                  alpha: _hovered ? 0.4 : 0.22,
                ),
              ),
            ),
            child: Text(
              widget.version,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoCheckChip extends StatelessWidget {
  const _AutoCheckChip({required this.selected, required this.onChanged});

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsButton(
      icon: selected
          ? Icons.check_circle_rounded
          : Icons.radio_button_unchecked_rounded,
      label: '启动时自动检查更新',
      active: selected,
      onPressed: () => onChanged(!selected),
    );
  }
}

class _LegalItem extends StatelessWidget {
  const _LegalItem({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              content,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.65,
              ),
            ),
          ),
        ],
      ),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.cleaning_services_rounded,
          title: '缓存管理',
          subtitle: '缓存用于提升加载与播放速度，超过上限会自动清理较早内容。',
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 52),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _CacheStatBadge(sizeText: sizeText),
              MenuAnchor(
                style: MenuStyle(
                  backgroundColor: WidgetStatePropertyAll(
                    AppColors.surfaceElevated,
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      side: BorderSide(color: AppColors.border),
                    ),
                  ),
                  elevation: const WidgetStatePropertyAll(4),
                ),
                menuChildren: _limits.map((limit) {
                  final selected = selectedLimit == limit;
                  return QualityMenuItem(
                    width: 140,
                    selected: selected,
                    leading: QualityBadge(
                      label: _limitBadge(limit),
                      selected: selected,
                    ),
                    title: '上限 ${_limitLabel(limit)}',
                    onPressed: () => onLimitChanged(limit),
                  );
                }).toList(),
                builder: (context, menuController, _) {
                  return _DropdownTriggerButton(
                    isOpen: menuController.isOpen,
                    onTap: busy
                        ? () {}
                        : () => menuController.isOpen
                              ? menuController.close()
                              : menuController.open(),
                    leading: QualityBadge(
                      label: _limitBadge(selectedLimit),
                      selected: true,
                    ),
                    label: '上限 ${_limitLabel(selectedLimit)}',
                  );
                },
              ),
              _SettingsButton(
                icon: Icons.delete_outline_rounded,
                label: busy ? '处理中' : '清理缓存',
                loading: busy,
                onPressed: busy ? null : onClear,
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

  static String _limitBadge(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024 / 1024).toInt()}G';
    }
    return '${(bytes / 1024 / 1024).toInt()}M';
  }
}

class _CacheStatBadge extends StatelessWidget {
  const _CacheStatBadge({required this.sizeText});

  final String sizeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.selected.withValues(
          alpha: AppColors.isDark ? 0.5 : 0.85,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '当前占用',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(width: 7),
          Text(
            sizeText,
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

class _PlaybackQualitySection extends StatelessWidget {
  const _PlaybackQualitySection({required this.controller});

  final PlaybackQualityController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final currentQuality = controller.quality;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: AppColors.isDark ? 0.14 : 0.08,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Icon(
                Icons.high_quality_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '播放音质',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '新歌曲优先按此音质解析，不可用时会自动选择可播放版本。',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            MenuAnchor(
              style: MenuStyle(
                backgroundColor: WidgetStatePropertyAll(
                  AppColors.surfaceElevated,
                ),
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: AppColors.border),
                  ),
                ),
                elevation: const WidgetStatePropertyAll(4),
              ),
              menuChildren: PlaybackQuality.values.map((quality) {
                final selected = currentQuality == quality;
                return QualityMenuItem(
                  width: 148,
                  selected: selected,
                  leading: QualityBadge(
                    label: quality.badge,
                    selected: selected,
                  ),
                  title: quality.title,
                  onPressed: () => controller.select(quality),
                );
              }).toList(),
              builder: (context, menuController, _) {
                return _DropdownTriggerButton(
                  isOpen: menuController.isOpen,
                  onTap: () => menuController.isOpen
                      ? menuController.close()
                      : menuController.open(),
                  leading: QualityBadge(
                    label: currentQuality.badge,
                    selected: true,
                  ),
                  label: currentQuality.title,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _DropdownTriggerButton extends StatefulWidget {
  const _DropdownTriggerButton({
    required this.isOpen,
    required this.onTap,
    this.leading,
    required this.label,
  });

  final bool isOpen;
  final VoidCallback onTap;
  final Widget? leading;
  final String label;

  @override
  State<_DropdownTriggerButton> createState() => _DropdownTriggerButtonState();
}

class _DropdownTriggerButtonState extends State<_DropdownTriggerButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isOpen
                ? AppColors.selected
                : _hovered
                ? AppColors.surfaceHover
                : AppColors.page,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: widget.isOpen
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : _hovered
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: widget.isOpen ? 0.5 : 0.0,
                duration: AppMotion.fast,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: widget.isOpen ? AppColors.primary : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingSwitchRow extends StatelessWidget {
  const _SettingSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: AppColors.isDark ? 0.14 : 0.08,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _SettingsButton extends StatefulWidget {
  const _SettingsButton({
    this.icon,
    required this.label,
    this.onPressed,
    this.active = false,
    this.loading = false,
  }) : isGhost = false,
       isPrimary = false;

  const _SettingsButton.ghost({required this.label, this.onPressed})
    : icon = null,
      active = false,
      isGhost = true,
      isPrimary = false,
      loading = false;

  const _SettingsButton.primary({
    required this.label,
    this.onPressed,
    this.loading = false,
  }) : icon = null,
       active = false,
       isGhost = false,
       isPrimary = true;

  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;
  final bool isGhost;
  final bool isPrimary;
  final bool loading;

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final isDark = AppColors.isDark;

    Color bg;
    Color fg;
    Color borderColor;

    if (widget.isPrimary) {
      bg = enabled
          ? (_hovered ? AppColors.primaryPressed : AppColors.primary)
          : AppColors.primary.withValues(alpha: 0.4);
      fg = Colors.white;
      borderColor = Colors.transparent;
    } else if (widget.isGhost) {
      bg = _hovered
          ? (isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05))
          : Colors.transparent;
      fg = _hovered ? AppColors.primary : AppColors.muted;
      borderColor = Colors.transparent;
    } else if (widget.active) {
      bg = AppColors.selected;
      fg = AppColors.primary;
      borderColor = AppColors.primary.withValues(alpha: 0.35);
    } else {
      bg = _hovered ? AppColors.surfaceHover : AppColors.page;
      fg = _hovered ? AppColors.text : AppColors.muted;
      borderColor = AppColors.border;
    }

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed
              ? 0.97
              : _hovered && enabled
              ? 1.02
              : 1.0,
          duration: AppMotion.fast,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.loading) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  ),
                  const SizedBox(width: 8),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, color: fg),
                  const SizedBox(width: 7),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12.5,
                    fontWeight: widget.isPrimary || widget.active
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
