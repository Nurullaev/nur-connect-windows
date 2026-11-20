# Nur Connect for Windows — modification notice

Nur Connect for Windows is an independent modified version of FlClashX.
Modifications by Nurullaev started on 2026-11-20.

Base: pluralplay/FlClashX, commit
`a9bbb66f6aec3e47359819c93976148a1d270e23`, version 0.5.8+2026111801.
FlClashX itself derives from chen08209/FlClash. The networking core is Mihomo
(MetaCubeX/mihomo); this base pins v1.19.34. Original copyright notices,
the root GPL v3 LICENSE and third-party license files remain in the source tree.

Initial modifications: Windows product name, process/service/data identifiers,
installer identity and removal of legacy FlClash adoption, own import schemes,
user-agent, update repository and artifact names, localized product text,
documentation and related regression expectations. Upstream provider-update
trust is removed pending provisioning of a Nur Connect public key.

Further modifications on 2026-11-20: a shared subscription-input parser, safe
import diagnostics, explicit HWID refusal handling, an import dialog retaining
its input for retries, and a dedicated responsive Windows home reusing existing
profile/server/setup actions. Windows toolchain validation and the first preview build started on
2026-11-21; current validation results are recorded in docs/windows/first-build.md. New UI strings are translated into Russian and English;
other locales fall back to English for these messages.

Further changes on 2026-11-21: a Windows server picker with local search,
latency checks and persisted selection; dedicated Windows settings; our website
links, Windows-only User-Agent and preview versioning.

The original icons remain temporary development assets. An independent visual
identity and a complete dependency/asset license inventory are pending before
distribution. No release, certification, sponsorship or endorsement by the
upstream authors is implied.

Source projects:

- https://github.com/Nurullaev/nur-connect-windows
- https://github.com/pluralplay/FlClashX
- https://github.com/chen08209/FlClash
- https://github.com/MetaCubeX/mihomo
