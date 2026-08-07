/// Bagisto API endpoint.
///
/// ⚠️ IMPORTANT — this is a PRIVATE LAN address. It is only reachable from a
/// device that is on the SAME local network as the server machine, and only
/// while the server's IP is exactly this value.
///
/// This is the #1 cause of "network error" on the phone while Postman (running
/// on the same PC as the server) works fine: the phone/emulator is not on this
/// LAN / cannot reach 192.168.1.7:8001.
///
/// Fixes:
///   • Android emulator → use  http://10.0.2.2:8001/graphql
///   • iOS simulator     → use  http://127.0.0.1:8001/graphql
///   • Real device       → use the PC's current LAN IP (must match Wi-Fi)
///   • Production         → use the public https domain, e.g.
///                          https://shop.example.com/graphql
///
/// You can also override this at runtime (without rebuilding) via the in-app
/// API settings sheet — see `api_settings_sheet.dart` / `ApiConfig.setEndpoint`.
const String bagistoEndpoint =
    'https://carlene-hygroscopic-recollectively.ngrok-free.dev/graphql';

/// Storefront key for Bagisto API
const String storefrontKey = 'your_storefront_key_here';

/// Default channel code used by request headers.
const String channelCode = 'default';

/// Default Bagisto channel ID used during app bootstrap.
const int channelId = 1;

/// Company name
const String companyName = 'Your Company Name';

/// Public storefront base URL (web version of the store).
/// Used to build links to legal pages (privacy policy, terms of use)
/// that are also shown inside the app via CMS pages.
/// Replace with the real domain before release.
const String storeBaseUrl = 'http://192.168.190.25/bagisto/public';

/// Privacy Policy page URL (GDPR). Points to the store's own CMS page.
const String privacyPolicyUrl = '$storeBaseUrl/page/privacy-policy';

/// Terms of Use page URL. Points to the store's own CMS page.
const String termsOfUseUrl = '$storeBaseUrl/page/terms-conditions';
