# 晴听音乐项目规则

## 项目信息

- 中文名：晴听音乐。
- 英文名及项目名：QingTingMusic。
- 项目路径：`D:\githubPro\IsleMusic`。
- 当前只维护 Windows 桌面端，不创建、恢复或维护 Web 版本。
- 默认启动页为“我的音乐”。
- 产品定位是简约、搜索优先的桌面音乐播放器。
- 不主动加入推荐信息流、复杂音效、私人 FM、云盘等非核心功能。

## UI 原则

- 使用通透亮色和晴空蓝主题。
- 蓝色只用于选中、播放进度和重点操作。
- 避免花花绿绿、多层卡片、大面积渐变和夸张圆角。
- 左侧导航只保留：我的音乐、搜索、设置。
- 搜索页突出搜索框，不堆放推荐内容。
- Windows 使用 `window_manager` 自定义标题栏，不显示 `QingTingMusic` 标题文字。
- 修改 UI 后检查 `1280x720` 和 `1536x900` 两种窗口尺寸。

## 架构规则

- `main.dart` 只负责初始化。
- 页面、组件、控制器、服务、模型和仓库分层维护。
- UI 不直接请求音乐 API。
- API 统一通过 `MusicRepository` 接入。
- 播放操作统一通过 `PlayerController` 和 `AudioPlayerService`。
- 文件存储统一通过 `AppStorageService`，偏好设置统一通过 `AppPreferencesService`，禁止各服务自行拼接系统目录。
- 不把账号、密码、Cookie、Token、设备密钥或其他凭证提交到仓库。

## 本地数据

- Windows 用户数据统一存放在 `D:\QingTingMusic\userdata`；无 D 盘或 D 盘不可写时，才回退到安装目录下的 `userdata`。
- 音频缓存、API 设置、登录会话、搜索历史、主题、音乐库缓存、最近播放和日志都必须遵守统一路径。
- 禁止把缓存或用户数据写入 `C:\Users\Public`、`LOCALAPPDATA`、`APPDATA` 或其他系统盘用户目录。
- 从旧版本升级时迁移并清理旧数据目录；迁移遇到权限错误时不得阻塞新版本启动。
- 覆盖升级保留 `userdata`；完整卸载必须删除程序及全部用户数据。

## 验证

- 完成代码修改后运行 `.\scripts\verify.ps1`。
- 验证内容包括格式化、静态检查、测试和 Windows release 构建。
- 只要修改了 Flutter 插件依赖，允许同步提交 Flutter 自动生成的 Windows 插件注册文件。
- 构建产物位于 `build\windows\x64\runner\Release\qing_ting_music.exe`。
- 发布安装包前必须实际验证：安装成功、生成卸载程序、覆盖升级保留 `userdata`、卸载后程序和 `userdata` 均被删除。
- 如果完整 Widget 测试因持续动画无法结束，必须运行受影响的单项测试、静态检查和 Windows 构建，并在结果中明确说明，不能把超时写成测试通过。

## Windows 发版

- 用户要求发布、构建新版本或生成安装包时，由 AI 直接完成，不把构建步骤交还给用户操作。
- 使用 `.\scripts\package.ps1 -Version <版本号> -BuildNumber <构建号>` 构建，版本号与构建号必须递增。
- 修复使用补丁版本，兼容性功能使用次版本，稳定正式版再使用 `1.0.0`。
- 安装器使用固定 `AppId`，保证新版本可以覆盖安装旧版本。
- 每次发布必须主动提供安装包路径、文件大小、SHA256、建议标签、中文 Release 标题及可直接粘贴的完整 Markdown。
- Release Markdown 必须包含真实更新内容、安装方式、升级/卸载说明、系统要求、已知限制和项目声明。
- 发布说明必须根据本次真实 Git 变更编写，不能沿用过期功能列表。
- 详细流程见 `docs/RELEASING.md`。

## Git

- 提交信息遵循 Conventional Commits 1.0.0：
  `https://www.conventionalcommits.org/en/v1.0.0/`
- 格式：`<type>[optional scope]: <中文描述>`。
- 类型和 scope 使用小写英文，描述使用中文。
- 常用类型：
  - `feat`：新增用户功能。
  - `fix`：修复问题。
  - `refactor`：不改变功能的结构调整。
  - `style`：纯视觉或格式调整。
  - `test`：测试调整。
  - `docs`：文档调整。
  - `build`：构建和依赖调整。
  - `chore`：其他维护工作。
- 示例：
  - `feat(search): 接入歌曲搜索接口`
  - `fix(player): 修复切歌后无法播放`
  - `refactor(api): 拆分音乐数据仓库`
  - `style(ui): 优化音乐库列表布局`
- 用户只说“提交”时，只提交，不推送。
- 用户说“推送”时，先验证、提交，再推送。
- 发布提交建议使用 `build(release): <中文版本说明>`；缺陷修复可使用 `fix(scope): <中文说明>`。
- GitHub 推送使用：

```powershell
git -c http.version=HTTP/1.1 -c http.proxy=http://127.0.0.1:10808 -c https.proxy=http://127.0.0.1:10808 push origin main
```
