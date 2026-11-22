#include "gpu_probe.h"

#include <d3d11.h>
#include <windows.h>

#include <cwchar>

namespace {

// Read by ANGLE inside flutter_windows.dll when it creates its display.
constexpr wchar_t kAngleOverridesVariable[] = L"ANGLE_FEATURE_OVERRIDES_ENABLED";
constexpr wchar_t kAllowEs3OnFl10[] = L"allowES3OnFL100";
constexpr wchar_t kInfoVariable[] = L"NUR_CONNECT_RENDERER_INFO";

// The highest feature level the default hardware adapter offers, the one
// ANGLE opens, or 0 when Direct3D 11 cannot create a device on it.
D3D_FEATURE_LEVEL HardwareFeatureLevel() {
  const D3D_FEATURE_LEVEL levels[] = {
      D3D_FEATURE_LEVEL_11_1, D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1,
      D3D_FEATURE_LEVEL_10_0, D3D_FEATURE_LEVEL_9_3,  D3D_FEATURE_LEVEL_9_2,
      D3D_FEATURE_LEVEL_9_1};
  D3D_FEATURE_LEVEL level = static_cast<D3D_FEATURE_LEVEL>(0);
  // Without a device to return, it only reports the level it would create.
  HRESULT result = ::D3D11CreateDevice(
      nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0, levels, ARRAYSIZE(levels),
      D3D11_SDK_VERSION, nullptr, &level, nullptr);
  if (result == E_INVALIDARG) {
    // A runtime without Direct3D 11.1 refuses a list that starts at 11_1.
    result = ::D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0,
                                 levels + 1, ARRAYSIZE(levels) - 1,
                                 D3D11_SDK_VERSION, nullptr, &level, nullptr);
  }
  return SUCCEEDED(result) ? level : static_cast<D3D_FEATURE_LEVEL>(0);
}

}  // namespace

void PrepareRenderer() {
  // An override someone set by hand is left as it is.
  const bool overridden =
      ::GetEnvironmentVariableW(kAngleOverridesVariable, nullptr, 0) > 0;
  if (!overridden) {
    ::SetEnvironmentVariableW(kAngleOverridesVariable, kAllowEs3OnFl10);
  }
  const unsigned level = static_cast<unsigned>(HardwareFeatureLevel());
  wchar_t info[96];
  swprintf_s(info, L"d3d=%u_%u es3-on-10_0=%s", (level >> 12) & 0xF,
             (level >> 8) & 0xF, overridden ? L"preset" : L"on");
  ::SetEnvironmentVariableW(kInfoVariable, info);
}
