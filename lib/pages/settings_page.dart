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
import '../widgets/page_header.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.updateController,
    required this.onCheckUpdates,
    required this.closeToTray,
    required this.onCloseToTrayChanged,
    required this.playbackQualityController,
    required this.themeController,
    this.onEndpointChanged,
    this.onDeveloperModeChanged,
  });

  final UpdateController updateController;
  final VoidCallback onCheckUpdates;
  final bool closeToTray;
  final ValueChanged<bool> onCloseToTrayChanged;
  final PlaybackQualityController playbackQualityController;
  final ThemeController themeController;
  final VoidCallback? onEndpointChanged;
  final ValueChanged<bool>? onDeveloperModeChanged;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('项目地址已复制')));
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
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                '开发者模式',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '输入口令后会显示后端接口、更新代理和诊断日志等调试工具。',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passphraseController,
                      obscureText: true,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: '开发者口令',
                        errorText: errorText.isEmpty ? null : errorText,
                        prefixIcon: const Icon(Icons.key_rounded, size: 20),
                        filled: true,
                        fillColor: AppColors.page,
                        border: const OutlineInputBorder(
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) {
                        _submitDeveloperPassphrase(
                          dialogContext,
                          setDialogState,
                          passphraseController.text,
                          (value) => errorText = value,
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    _submitDeveloperPassphrase(
                      dialogContext,
                      setDialogState,
                      passphraseController.text,
                      (value) => errorText = value,
                    );
                  },
                  child: const Text('开启'),
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
        return AlertDialog(
          backgroundColor: AppColors.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 24,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Text(
            '免责声明与版权声明',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
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
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
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
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(title, style: TextStyle(color: AppColors.text)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 420),
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
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.of(context).pop();
                _showSnack('内容已复制');
              },
              child: const Text('复制'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message) {
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
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            '自定义主题色',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  height: 72,
                  decoration: BoxDecoration(
                    color: color.toColor(),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '晴听音乐',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(color.toColor()),
              child: const Text('应用'),
            ),
          ],
        ),
      ),
    );
    if (selected != null) await widget.themeController.setAccentColor(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 30, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: '设置', subtitle: '调整晴听音乐的使用偏好'),
          const SizedBox(height: 22),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppColors.isDark ? null : AppShadows.soft,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AppearanceSection(
                      controller: widget.themeController,
                      onCustomColor: _showAccentPicker,
                    ),
                    Divider(
                      height: 30,
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
                      height: 30,
                      color: AppColors.divider.withValues(alpha: 0.72),
                    ),
                    _PlaybackQualitySection(
                      controller: widget.playbackQualityController,
                    ),
                    Divider(
                      height: 30,
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
                      height: 30,
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
                      const Divider(height: 30),
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.palette_outlined, color: AppColors.primary, size: 21),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '外观',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '主题色会影响选中状态、按钮和页面氛围，品牌图标仍保持原色。',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.light_mode_rounded, size: 17),
                        label: Text('浅色'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.dark_mode_rounded, size: 17),
                        label: Text('深色'),
                      ),
                    ],
                    selected: {controller.isDark},
                    onSelectionChanged: (value) =>
                        controller.setDarkMode(value.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 18),
                  for (final color in colors) ...[
                    _ThemeSwatch(
                      color: color,
                      selected:
                          controller.accentColor.toARGB32() == color.toARGB32(),
                      onTap: () => controller.setAccentColor(color),
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: onCustomColor,
                    icon: const Icon(Icons.colorize_rounded, size: 17),
                    label: const Text('自定义'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: controller.resetAccentColor,
                    child: const Text('恢复默认'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '使用此主题色',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.text : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
            : null,
      ),
    ),
  );
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.code_rounded, color: AppColors.primary, size: 21),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '开发者管理',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onDisable,
                    child: const Text('关闭开发者模式'),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '调试接口、升级代理和运行日志。普通使用无需调整这些选项。',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 9),
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
              const SizedBox(height: 9),
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
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onCopyDiagnostics,
                    icon: const Icon(Icons.content_copy_rounded, size: 17),
                    label: const Text('复制诊断信息'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onShowPlaybackLog,
                    icon: const Icon(Icons.article_outlined, size: 17),
                    label: const Text('查看播放日志'),
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
        const SizedBox(height: 5),
        Text(
          description,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  prefixIcon: Icon(icon, size: 20),
                  filled: true,
                  fillColor: AppColors.page,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: saving ? null : onSave,
              child: Text(
                saving
                    ? '保存中'
                    : saved
                    ? '已保存'
                    : '保存',
              ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 21),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '关于晴听音乐',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onVersionTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '当前版本 $version',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    selected: controller.autoCheck,
                    label: const Text('启动时自动检查更新'),
                    onSelected: (value) {
                      controller.setAutoCheck(value);
                    },
                    selectedColor: AppColors.selected,
                    checkmarkColor: AppColors.primary,
                    backgroundColor: AppColors.page,
                    side: BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: checking ? null : onCheckUpdates,
                    icon: checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt_rounded, size: 18),
                    label: Text(checking ? '检查中' : '检查更新'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onProjectTap,
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('项目地址'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onLegalTap,
                    icon: const Icon(Icons.gavel_rounded, size: 17),
                    label: const Text('声明'),
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

class _PlaybackQualitySection extends StatelessWidget {
  const _PlaybackQualitySection({required this.controller});

  final PlaybackQualityController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.high_quality_rounded,
              color: AppColors.primary,
              size: 21,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '播放音质',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '新歌曲优先按此音质解析，不可用时会自动选择可播放版本。',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.page,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.divider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<PlaybackQuality>(
                  value: controller.quality,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  dropdownColor: AppColors.surface,
                  iconEnabledColor: AppColors.muted,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  items: PlaybackQuality.values
                      .map(
                        (quality) => DropdownMenuItem(
                          value: quality,
                          child: Text(
                            quality == PlaybackQuality.standard
                                ? '标准音质'
                                : '${quality.label} 音质',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) controller.select(value);
                  },
                ),
              ),
            ),
          ],
        );
      },
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
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 21),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
