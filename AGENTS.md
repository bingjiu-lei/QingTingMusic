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
- 不把账号、密码、Cookie、Token、设备密钥或其他凭证提交到仓库。

## 验证

- 完成代码修改后运行 `.\scripts\verify.ps1`。
- 验证内容包括格式化、静态检查、测试和 Windows release 构建。
- 只要修改了 Flutter 插件依赖，允许同步提交 Flutter 自动生成的 Windows 插件注册文件。
- 构建产物位于 `build\windows\x64\runner\Release\qing_ting_music.exe`。

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
- GitHub 推送使用：

```powershell
git -c http.version=HTTP/1.1 -c http.proxy=http://127.0.0.1:10808 -c https.proxy=http://127.0.0.1:10808 push origin main
```
