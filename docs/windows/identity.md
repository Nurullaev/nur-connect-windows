# Идентификаторы Nur Connect для Windows

Зафиксированы 20.11.2026. Общие значения приложения и упаковщика находятся в
`lib/common/product_identity.dart`. Нативные ресурсы C++/Rust, CMake и YAML
содержат согласованные значения; при изменении нужно проверять обе стороны.

| Назначение | Stable | Pre |
|---|---|---|
| Название | Nur Connect | Nur Connect Pre |
| Программа | NurConnect.exe | NurConnectPre.exe |
| Служба / EXE без расширения | NurConnectWindowsHelper | NurConnectWindowsPreHelper |
| AppUserModelID | org.nurconnect.windows | org.nurconnect.windows.pre |
| Данные под `%APPDATA%` | Nurullaev\NurConnectWindows | Nurullaev\NurConnectWindows.pre |
| URI scheme | nurconnect-win | nurconnect-win-pre |
| Installer AppId | 6C4AE483-BA2C-4EE6-80A3-E4EFAC4D1D4D | 4C0E593A-13A5-4E3C-8F6B-95A400B43B00 |
| Notifications CLSID | d8c0a9b6-f792-40d5-935f-bc9a2a97508e | e1424dab-1348-404b-b3b6-1ec9047a4842 |

Четыре GUID созданы через UUID v4, исходные GUID не переиспользуются.
Путь данных определяется `CompanyName=Nurullaev` и `ProductName=NurConnectWindows[.pre]`
в `windows/runner/Runner.rc`, которые использует Windows path_provider.

Общие имена:

- Ядро: `NurConnectCore.exe`.
- Канал ядра: `\\.\pipe\NurConnectCore_<128-bit random suffix>`.
- Ключ порта службы: `HKLM\SYSTEM\CurrentControlSet\Services\<имя службы>\Runtime`, значение `Port`.
- Служба публикует динамический порт. Резервный порт standalone helper: 47891.
- Блокировка в собственном каталоге данных: `NurConnect.lock`.
- Логи и архивы: `NurConnect_*`.
- User-Agent: `Nur-Connect-Windows/v<версия> core/<версия Mihomo> Platform/windows`.
- Репозиторий обновлений: `Nurullaev/nur-connect-windows`.
- Файлы выпуска: `NurConnect-windows-<arch>-setup.exe` и `.zip`.

Windows регистрирует только URI scheme своего канала. Старые схемы Clash
допускаются при разборе переданного импорта, но их обработчики не перезаписываются.
Автоматический импорт Pre читает только соседний стабильный каталог Nur Connect;
installer adoption/retirement старого FlClash/FlClashX удалён.

Внутренние имена `fl_clash`, Android method channels `com.follow.clashx/*`,
флаг сборки `FLCLASHX_CHANNEL`/`FLCLASHX_PRE`, заголовки `flclashx-*` и версия
внутреннего helper-протокола сохранены. Они не являются идентичностью установки
Windows. Имена Linux/macOS в исходном каркасе не объявляют поддержку этих платформ.
Windows HWID и правила DNS/TUN/маршрутизации этим этапом не изменялись.

Публичный ключ provider updates пока отсутствует: такие обновления отвергаются.
Обычный GitHub updater использует наш репозиторий и наши имена файлов; релизов
Nur Connect пока нет. Приватные ключи и подписки в исходники не добавляются.
