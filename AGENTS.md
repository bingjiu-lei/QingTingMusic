# 晴听音乐项目规则

## 项目信息

- 中文名：晴听音乐。
- 英文名与项目名：QingTingMusic。
- 项目目录：`D:\githubPro\IsleMusic`。
- 当前只维护 Windows 桌面端，不创建、恢复或维护 Web 版本。
- 默认启动页是“我的音乐”。
- 产品定位是简洁、搜索优先的个人音乐播放器，不主动堆叠推荐信息流和复杂入口。

## 开发前

- 先阅读 `docs/AI_DEVELOPMENT_GUIDE.md`。
- 运行 `git status --short`，保留用户和其他协作者尚未提交的改动。
- 一次只处理明确的一组相关需求，不顺手重构无关模块。
- 开始修改前先确认需求是否已经完成，避免重复实现。

## 架构边界

- `main.dart` 只负责应用初始化。
- 页面、组件、控制器、服务、模型和数据仓库分层维护。
- UI 不直接请求音乐 API，统一通过 `MusicRepository`。
- 播放状态统一通过 `PlayerController`，底层播放统一通过 `AudioPlayerService`。
- Windows 播放后端使用 `just_audio_media_kit` 和 `libmpv`，不得恢复为 `just_audio_windows`。
- 文件统一通过 `AppStorageService`，偏好设置统一通过 `AppPreferencesService`。
- 不把账号、Cookie、Token、设备密钥或其他凭证提交到仓库。

## 数据与缓存

- Windows 用户数据优先放在 `D:\QingTingMusic\userdata`。
- 无 D 盘或 D 盘不可写时，才回退到安装目录下的 `userdata`。
- 禁止把缓存和用户数据写入 `C:\Users\Public`、`LOCALAPPDATA` 或 `APPDATA`。
- 在线 URL 负责当前播放，音频缓存只能在后台进行；缓存失败不得中断播放。
- 覆盖升级必须保留用户数据，完整卸载必须删除程序和用户数据。

## UI 原则

- 保持晴空蓝、白色和冷浅灰的简洁风格。
- 蓝色只用于选中、播放进度和重要操作。
- 避免多层卡片、大面积渐变、夸张圆角和花哨动效。
- 左侧导航保持“我的音乐、搜索、设置”三个主入口。
- 修改 UI 后检查 `1280x720` 和 `1536x900`，同时考虑未来 Android 端的信息结构复用。

## 开发策略

- 使用统一的开发流程，避免不同实现习惯在状态管理、UI 风格和验证方式上互相打架。
- 简单 UI、文案、间距和局部交互可以快速处理，但仍要遵守现有主题和组件风格。
- 播放状态、API、账号会话、缓存、分页、后台运行和跨模块重构必须整体分析后再修改。
- 涉及第三方官方接口、隐藏功能、下载功能或版权边界时，必须先分析方案和风险，不直接实现。

## 验证

- 完成代码修改后默认运行 `.\scripts\verify.ps1`。
- `.\scripts\verify.ps1` 默认执行格式化、静态检查、核心单测和 Windows 构建，不默认跑全量 Widget 测试，避免持续动画或插件初始化拖住开发。
- 需要完整 UI 回归时运行 `.\scripts\verify.ps1 -FullTests`；如需限制等待时间，可加 `-FullTestTimeoutSeconds 180`。
- 只想快速检查代码时可以运行 `.\scripts\verify.ps1 -SkipBuild`。
- 修改播放器时至少运行 `flutter test test\player_controller_test.dart` 和 Windows Release 构建。
- 修改 Flutter 插件时提交自动生成的 Windows 插件注册文件。
- 如果完整 Widget 测试仍因持续动画超时，必须如实说明，并运行静态检查、相关单测和 Windows 构建。

## Git 与发布

- 提交信息遵循 Conventional Commits：`<type>(<scope>): <中文描述>`。
- 用户说“提交”时只提交；用户说“推送”时验证、提交并推送。
- 未经用户要求，不创建版本号、标签或 Release。
- 发布时阅读 `docs/RELEASING.md`，使用 `.\scripts\package.ps1` 构建并验证安装、升级和卸载。
- 每次发布主动提供中文 Release Markdown、安装包大小和 SHA256。
- GitHub 推送使用：

```powershell
git -c http.version=HTTP/1.1 -c http.proxy=http://127.0.0.1:10808 -c https.proxy=http://127.0.0.1:10808 push origin main
```
