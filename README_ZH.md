<p align="center"><img src="docs/assets/banner.svg" alt="Nur Connect for Windows" width="100%"></p>

<p align="center"><a href="README.md">Русский</a> · <a href="README_EN.md">English</a> · <a href="https://nurconnect.app">官网</a></p>

# Nur Connect Windows 版

基于 [FlClashX](https://github.com/pluralplay/FlClashX)、[FlClash](https://github.com/chen08209/FlClash) 和 [Mihomo](https://github.com/MetaCubeX/mihomo) 的独立 Windows 客户端。

- 专用首页：连接状态、所选服务器和订阅信息。
- 订阅导入：安全的错误提示，保留输入以便重试。
- 服务器搜索、排序、延迟测试和选择保存。
- Windows 设置：TUN、系统代理、开机启动、语言、主题和诊断。
- 独立的进程、服务、数据目录和导入协议。

首个预览版本为 **0.1.0-pre.1**。请参阅[构建状态及限制](docs/windows/first-build.md)和[路线图](docs/windows/roadmap.md)。应用图标暂时沿用上游资源。新界面文本支持俄语和英语，其他语言暂用英语。分支的 GitHub Actions 尚未启用。

在 Windows 上安装 Flutter、Go、Rust MSVC（本机 API 使用 `1.99.0`）、Visual Studio C++/CMake/Windows SDK 和 Inno Setup 6 后：

```powershell
flutter pub get
flutter analyze
flutter test
dart setup.dart windows --env pre --arch amd64
```

构建产物位于 `dist/`。仅生成便携压缩包可添加 `--targets zip`。

采用 [GNU GPL v3](LICENSE) 许可证，保留原作者及第三方许可信息，详情见 [NOTICE](NOTICE.md)。基础版本：FlClashX `a9bbb66f6aec3e47359819c93976148a1d270e23`、Mihomo `v1.19.34`。本项目与同名移动端项目分开开发，并非上游官方发行版。
