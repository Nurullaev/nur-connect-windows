# Nur Connect для macOS — локальная разработка

23 ноября 2026 года. Локальная ветка `work/nur-connect-macos` от Windows 1.0.8
(`56a9d118`). Эта ветка и её пакеты пока не опубликованы.

Один Universal 2 DMG для Intel и Apple Silicon. Минимальная система — **macOS 13
Ventura**: Go-ядро и часть native-assets библиотек требуют 13.0. Интерфейс главной,
серверов и настроек общий с текущей Windows-версией Nur Connect. Мобильные проекты
не используются.

| Назначение | Stable | Pre |
|---|---|---|
| Приложение | Nur Connect.app | Nur Connect Pre.app |
| Bundle ID / настройки | org.nurconnect.macos | org.nurconnect.macos.pre |
| Схема импорта | nurconnect-mac | nurconnect-mac-pre |
| Данные | ~/Library/Application Support/org.nurconnect.macos | ~/Library/Application Support/org.nurconnect.macos.pre |
| Привилегированное ядро | /Library/Application Support/org.nurconnect.macos/NurConnectCore | /Library/Application Support/org.nurconnect.macos.pre/NurConnectCore |

Ядро внутри пакета — `Contents/MacOS/NurConnectCore`. Его копия для TUN
устанавливается с запросом администратора; служба Windows на Mac не используется.
Приложение не требует установки FlClashX и не импортирует его данные автоматически.
Исходные авторы и GPL-3.0 сохранены в сведениях о программе и лицензиях.

Выбор приложения в исключениях читает `CFBundleExecutable` из выбранного `.app`.
Автоматические торрент-исключения используют имена процессов macOS, включая
uTorrent Neo, qBittorrent и Transmission. Правила Windows остаются отдельными.

## Локальная сборка

Нужны Xcode с принятыми условиями, Go и Rust, а также Flutter, совпадающий с
Windows-сборкой: commit `5fc346839b5d0eef006ed8404392afb4dfae428d` (3.47.6).
Rust закреплён проектом на 1.99.0; нужны `aarch64-apple-darwin` и
`x86_64-apple-darwin`. Сборку и тесты лучше запускать в отдельных временных копиях,
чтобы не помещать SDK-кэши и гигабайты промежуточных файлов в iCloud.

```sh
flutter pub get
dart run intl_utils:generate
dart run build_runner build
dart run setup.dart macos --env pre
```

`setup.dart` оставляет продукт Flutter на месте, а для пакета создаёт отдельную
копию с именем канала. Ядро собирается в двух архитектурах и объединяется через
`lipo`. Перед упаковкой каждый Mach-O в приложении проверяется на наличие обеих
архитектур, включая Rust, SQLite и вспомогательную программу автозапуска.
DMG создаёт системный `hdiutil`; глобальные npm-пакеты не требуются.

Результат: `dist/NurConnect-macos-universal.dmg` и `.dmg.sha256`.
Текущая сохранённая локальная копия — `dist/macos-local/` (не отслеживается Git).
Обычная локальная подпись ad-hoc нужна для запуска; она не является Developer ID
и не заменяет нотариализацию Apple.

## Перед публичным выпуском

- Проверить импорт настоящей тестовой подписки и заголовки на Mac; отдельно
  добавить точное правило панели для `Nur-Connect-macOS/v… Platform/macos`.
  В рабочей панели этой веткой ничего не менялось.
- Проверить TUN с ручным вводом пароля администратора, системный прокси,
  восстановление DNS/прокси после остановки и выхода, сон/пробуждение и автозапуск.
- Проверить полный интерфейс на Intel Mac: запуск Intel-ядра через Rosetta и
  наличие двух срезов в пакете не заменяют испытание всей программы на Intel.
- Получить Apple Developer, настроить Developer ID, hardened runtime,
  нотариализацию и stapling. Испытать обновление с подписью и Gatekeeper на чистом
  Mac, затем опубликовать соответствующие исходники и DMG по решению владельца.

Обновления ищут единый `NurConnect-macos-universal.dmg` в репозитории Nur Connect;
пакеты Windows и upstream не подставляются вместо него. Проверка подписи и
идентификатора устанавливаемого обновления сохранена.
