# 晴听音乐 Windows 发版

## 版本规则

- 修复问题：递增补丁版本，例如 `0.1.0 -> 0.1.1`
- 增加兼容功能：递增次版本，例如 `0.1.1 -> 0.2.0`
- 正式稳定版：使用 `1.0.0`
- `BuildNumber` 每次发布递增

## 构建安装包

确认已安装 Flutter、Visual Studio C++ 生成工具和 Inno Setup 6，然后在项目根目录执行：

```powershell
.\scripts\package.ps1 -Version 0.1.1 -BuildNumber 2
```

脚本会自动：

1. 更新 `pubspec.yaml` 版本。
2. 清理并构建 Windows Release。
3. 生成带卸载程序的安装包。
4. 输出安装包路径和 SHA256。

安装包位于：

```text
dist\QingTingMusic-Setup-v0.1.1-x64.exe
```

## 发布到 GitHub

1. 提交并推送版本代码。
2. 在 GitHub Releases 创建与版本一致的标签，例如 `v0.1.1`。
3. 上传 `dist` 目录中的安装包。
4. 填写更新内容和 SHA256 后发布。

## 升级和卸载

- 安装器使用固定 `AppId`，新版本可以直接覆盖旧版本。
- 覆盖升级会保留安装目录中的 `userdata`。
- 完整卸载会删除程序、缓存、账号会话和其他用户数据。
- 首次安装默认优先使用 `D:\QingTingMusic`，安装界面可以修改位置。
