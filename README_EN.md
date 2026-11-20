<p align="center"><img src="docs/assets/banner.svg" alt="Nur Connect for Windows" width="100%"></p>

<p align="center"><a href="README.md">Русский</a> · <a href="README_ZH.md">简体中文</a> · <a href="https://nurconnect.app">Website</a> · <a href="https://github.com/Nurullaev/nur-connect-windows/releases">Releases</a></p>

# Nur Connect for Windows

An independent Windows client built on [FlClashX](https://github.com/pluralplay/FlClashX), [FlClash](https://github.com/chen08209/FlClash) and [Mihomo](https://github.com/MetaCubeX/mihomo).

- Dedicated home with connection status, selected server and subscription details.
- Subscription import with safe error messages and in-place retry.
- Server search, sorting and latency checks that preserve your selection.
- Windows settings: TUN, system proxy, startup, background launch, language, theme and diagnostics.
- Independent app, helper, data-directory and URI identities.

The first preview is **0.1.0-pre.1**. See [build status and limitations](docs/windows/first-build.md) and the [roadmap](docs/windows/roadmap.md). App icons remain temporary upstream assets. New messages support Russian and English; other locales fall back to English. Fork Actions remain disabled until our release workflows are prepared.

Build on Windows with Flutter, Go, Rust MSVC (`1.99.0` for the native API), Visual Studio C++ tools/CMake/Windows SDK and Inno Setup 6:

```powershell
flutter pub get
flutter analyze
flutter test
dart setup.dart windows --env pre --arch amd64
```

Outputs go to `dist/`. Add `--targets zip` for a portable archive only. Provider-signed updates require our own signing keys; the upstream key is no longer trusted.

[GPL v3](LICENSE). Original author credits and third-party licenses are retained; see [NOTICE](NOTICE.md). Source base: FlClashX `a9bbb66f6aec3e47359819c93976148a1d270e23`, Mihomo `v1.19.34`. This is a separate project from the similarly named mobile apps and is not an official upstream release.
