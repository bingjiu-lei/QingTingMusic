<div align="center">
  <img src="assets/images/app_icon_light.png" width="120" alt="晴听音乐" />
  <h1>晴听音乐</h1>
  <p>搜索够直接，推荐有分寸，播放更顺手的 Windows 音乐播放器。</p>
  <p>
    <a href="https://github.com/bingjiu-lei/QingTingMusic/releases/latest">下载最新版</a>
    ·
    <a href="#界面预览">界面预览</a>
    ·
    <a href="https://github.com/bingjiu-lei/QingTingMusic/issues">问题反馈</a>
  </p>
</div>

---

晴听音乐把个人音乐库、搜索、每日推荐和私人 FM 放在一套安静的桌面界面里。

知道想听什么时，直接搜索；不知道听什么时，让每日推荐或私人 FM 接上。没有花里胡哨的信息流。

## 界面预览

### 我的音乐

收藏歌曲、歌单、专辑、歌手、云盘和最近播放集中管理。

![我的音乐](docs/images/library.png)

### 搜索

搜索歌曲、歌手、歌单和专辑，支持联想与最近搜索。

![搜索](docs/images/search.png)

### 推荐

每日推荐和私人 FM，想听熟悉的，也能听点新鲜的。

![推荐](docs/images/recommendation.png)

### 播放页

沉浸查看封面与歌词，保留必要的播放、收藏、音质和队列控制。

![播放页](docs/images/playing.png)

### 歌手 / 专辑详情

从歌曲进入对应歌手或专辑；多位歌手可以逐个选择，不再把整串名字一起搜索。

![歌手或专辑详情](docs/images/detail.png)

### 设置

切换深浅模式和主题颜色，管理缓存、播放音质、后台行为与应用更新。

![设置](docs/images/settings.png)

## 主要功能

- 酷狗账号扫码与手机验证码登录
- 搜索歌曲、歌手、歌单和专辑，支持联想与最近搜索
- 收藏歌曲、歌单、专辑和歌手；查看云盘与最近播放
- 每日推荐与私人 FM，支持频道和偏好选择
- 播放队列、歌词、进度拖动、音量、后台播放与多种播放模式
- 标准、HQ、无损等可用音质；支持本地缓存和播放状态恢复
- 浅色、深色、预设主题色与自定义取色

## 下载与安装

前往 [Releases](https://github.com/bingjiu-lei/QingTingMusic/releases/latest) 下载 Windows 安装包：

```text
QingTingMusic-Setup-v版本号-x64.exe
```

支持 Windows 10 和 Windows 11 64 位系统。已安装旧版本时，直接运行新安装包即可覆盖升级。

> 安装包暂未进行数字签名。如果 Windows SmartScreen 显示提示，请点击“更多信息”，再选择“仍要运行”。


## 关于这个项目

晴听音乐是一个个人学习与技术实践项目，使用 Flutter 开发，目前只维护 Windows 桌面端。

项目希望把搜索、个人音乐库、克制推荐和稳定播放做得直接、舒服、可靠，而不是追求入口最多。

## 反馈

遇到问题或有建议，可以前往 [Issues](https://github.com/bingjiu-lei/QingTingMusic/issues)。反馈时建议附上：

- Windows 版本
- 晴听音乐版本
- 出现问题前进行的操作
- 错误提示或截图

## 项目声明

本项目仅用于个人学习和技术研究，不提供或存储音乐资源。

音乐、账号及相关数据通过酷狗官方接口获取。请遵守平台规则，尊重音乐版权并支持正版内容，请勿用于商业用途或违法行为。

<details>
<summary>参与开发</summary>

```powershell
flutter pub get
flutter run -d windows
```

提交代码前请运行：

```powershell
.\scripts\verify.ps1
```

</details>
