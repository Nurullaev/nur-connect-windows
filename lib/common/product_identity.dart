// Public identity of Nur Connect desktop applications.
// Keep OS resources, the helper and packaging in sync (docs/windows/identity.md).
const productName = 'Nur Connect';
const productFileName = 'NurConnect';
const windowsExecutableName = productFileName;
const windowsPreExecutableName = 'NurConnectPre';
const windowsCoreName = 'NurConnectCore';
const windowsHelperName = 'NurConnectWindowsHelper';
const windowsPreHelperName = 'NurConnectWindowsPreHelper';
const windowsAppId = 'org.nurconnect.windows';

/// The publisher, which Windows also takes for the data folder's parent.
const windowsCompanyName = 'Nur Dev';

/// The data folder's parent up to 1.0.1, moved once by [AppPath].
const legacyWindowsCompanyName = 'Nurullaev';
const windowsDataDirectory = '$windowsCompanyName\\NurConnectWindows';
const windowsPreDataDirectory = '$windowsCompanyName\\NurConnectWindows.pre';
const windowsProtocolScheme = 'nurconnect-win';
const windowsPreProtocolScheme = 'nurconnect-win-pre';
const windowsInstallerId = '6C4AE483-BA2C-4EE6-80A3-E4EFAC4D1D4D';
const windowsPreInstallerId = '4C0E593A-13A5-4E3C-8F6B-95A400B43B00';
const windowsNotificationGuid = 'd8c0a9b6-f792-40d5-935f-bc9a2a97508e';
const windowsPreNotificationGuid = 'e1424dab-1348-404b-b3b6-1ec9047a4842';
const productRepository = 'Nurullaev/nur-connect-windows';
const productWebsite = 'https://nurconnect.app';
const productUserAgent = 'Nur-Connect-Windows';
const productLockFile = 'NurConnect.lock';

const macosBundleId = 'org.nurconnect.macos';
const macosProductName = 'Nur Connect';
const macosCoreName = 'NurConnectCore';
const macosProtocolScheme = 'nurconnect-mac';
const macosPreProtocolScheme = 'nurconnect-mac-pre';
const macosUserAgent = 'Nur-Connect-macOS';
