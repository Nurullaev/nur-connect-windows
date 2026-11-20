<p align="center"><img src="docs/assets/banner.svg" alt="Nur Connect for Windows" width="100%"></p>

<p align="center">
  <a href="https://nurconnect.app">Сайт</a> ·
  <a href="https://github.com/Nurullaev/nur-connect-windows/releases">Выпуски</a> ·
  <a href="docs/windows/roadmap.md">План развития</a> ·
  <a href="README_EN.md">English</a> ·
  <a href="README_ZH.md">简体中文</a>
</p>

# Nur Connect для Windows

Подписка, выбор сервера и управление подключением в одном Windows-приложении.
Самостоятельный проект на базе [FlClashX](https://github.com/pluralplay/FlClashX),
[FlClash](https://github.com/chen08209/FlClash) и ядра [Mihomo](https://github.com/MetaCubeX/mihomo).

## Что уже есть

- Своя главная: подключение, выбранный сервер, подписка, срок и трафик.
- Импорт подписки со ссылкой, которая сохраняется при ошибке для повторной попытки.
- Понятные сообщения о неверном формате и подтверждённом отказе по HWID.
- Поиск серверов, сортировка, проверка задержки и сохранение выбранного узла.
- Настройки Windows: TUN, системный прокси, автозапуск, запуск свёрнутым, язык и тема.
- Доступ к профилям, резервным копиям, логам и расширенным настройкам.
- Собственные процессы, служба, URI-схемы и каталоги данных для установки отдельно от FlClashX.

Новые экраны переведены на русский и английский. Остальные локали используют
английский текст для новых сообщений. Приложение для Windows развивается отдельно
от одноимённых мобильных проектов.

## Текущий этап

Готовится первая предварительная версия **0.1.0-pre.1**. Проверки и ограничения
публикуются в [документе первой сборки](docs/windows/first-build.md).
Иконки приложения пока взяты из исходной базы. Actions форка отключены;
унаследованные workflows ещё не адаптированы для наших выпусков.

Сайт: **[nurconnect.app](https://nurconnect.app)**.

## Сборка из исходников

Нужна Windows с Flutter/Dart, Go, Rust MSVC, Visual Studio Build Tools (Desktop
C++, CMake и Windows SDK), а для установщика — Inno Setup 6.
Закреплённая версия Rust для native API: `1.99.0`.

```powershell
git clone --recurse-submodules https://github.com/Nurullaev/nur-connect-windows.git
cd nur-connect-windows
flutter config --enable-windows-desktop
flutter pub get
flutter analyze
flutter test
dart setup.dart windows --env pre --arch amd64
```

Для одного переносимого архива добавьте `--targets zip`. Пакеты находятся в
`dist/`. Подробности среды и фактических проверок — в документе первой сборки.
Для собственных подписанных обновлений нужны свои ключи, которые нельзя хранить
в публичном репозитории.

## Документация

| Документ | Содержание |
| --- | --- |
| [План работ](docs/windows/roadmap.md) | Сделанное и следующие этапы |
| [Идентификаторы Windows](docs/windows/identity.md) | EXE, служба, AppData, схемы импорта и User-Agent |
| [Первая сборка](docs/windows/first-build.md) | Проверки, toolchain и ограничения |
| [NOTICE](NOTICE.md) | Происхождение и наши изменения |

Внутреннее имя Dart-пакета `fl_clash` и совместимые заголовки подписки
`flclashx-*` сохранены. Поддерживаемая платформа этого форка — Windows;
каталоги остальных платформ унаследованы из базы.

## Открытый код и авторы

Лицензия — [GNU GPL v3](LICENSE). Исходный код, сведения об авторах и лицензии
компонентов сохранены. Изменения Nur Connect начаты 20 ноября 2026 года.
При распространении изменённых сборок нужно предоставлять соответствующие
исходники и соблюдать условия лицензий.

База: FlClashX `0.5.8+2026111801`, коммит
`a9bbb66f6aec3e47359819c93976148a1d270e23`; Mihomo `v1.19.34`.
Nur Connect не является официальным выпуском FlClashX, FlClash или Mihomo.
