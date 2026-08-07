import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_constants.dart';

/// Runtime-overridable API configuration.
///
/// The base endpoint normally comes from [bagistoEndpoint] (compile-time
/// constant). During development/integration testing it's convenient to point
/// the app at a colleague's backend without rebuilding, so this class keeps an
/// optional override in [SharedPreferences] and exposes a synchronous cached
/// getter used everywhere the endpoint is needed.
///
/// Usage:
///   1. Call [ApiConfig.load] once during app bootstrap (after
///      SharedPreferences is ready) to populate the cache.
///   2. Read [ApiConfig.endpoint] / [ApiConfig.origin] anywhere.
///   3. Call [ApiConfig.setEndpoint] to change it at runtime, then rebuild
///      the GraphQL clients (e.g. restart the app or re-create providers).
class ApiConfig {
  ApiConfig._();

  /// SharedPreferences key for the overridden GraphQL endpoint.
  static const String _endpointKey = 'api_config_endpoint_override';

  /// Cached endpoint, initialized from [bagistoEndpoint] and updated by
  /// [load] / [setEndpoint]. Kept synchronous so non-async call sites
  /// (image URL builders, HttpLink construction) can read it directly.
  static String _endpoint = bagistoEndpoint;

  /// The active GraphQL endpoint (e.g. `http://192.168.1.126:8001/graphql`).
  static String get endpoint => _endpoint;

  /// The scheme + host + port + path prefix of the active endpoint.
  /// Handles subfolders (e.g., `http://192.168.9.103/bagisto/public/graphql`
  /// becomes `http://192.168.9.103/bagisto/public`) to prevent broken image/asset URLs.
  static String get origin {
    final ep = _endpoint.trim();
    if (ep.toLowerCase().endsWith('/graphql')) {
      return ep.substring(0, ep.length - 8);
    }
    return Uri.parse(ep).origin;
  }

  /// The compile-time default endpoint, for "reset" actions and display.
  static String get defaultEndpoint => bagistoEndpoint;

  /// Whether the active endpoint differs from the compile-time default.
  static bool get isOverridden => _endpoint != bagistoEndpoint;

  /// Load any saved override into the synchronous cache. Call once at startup.
  static Future<void> load([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final saved = p.getString(_endpointKey);
    if (saved != null && saved.trim().isNotEmpty) {
      if (saved.contains('192.168.9.103') || saved.contains('192.168.9.108')) {
        await p.remove(_endpointKey);
        _endpoint = bagistoEndpoint;
      } else {
        _endpoint = saved.trim();
      }
    } else {
      _endpoint = bagistoEndpoint;
    }
    debugPrint('🌐 ApiConfig.load → endpoint = $_endpoint');
  }

  /// Persist and activate a new endpoint. Accepts either a full GraphQL URL
  /// (ending in `/graphql`) or a base URL/host — see [normalize].
  ///
  /// Returns the normalized endpoint that was stored.
  static Future<String> setEndpoint(
    String raw, [
    SharedPreferences? prefs,
  ]) async {
    final normalized = normalize(raw);
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_endpointKey, normalized);
    _endpoint = normalized;
    debugPrint('🌐 ApiConfig.setEndpoint → $normalized');
    return normalized;
  }

  /// Clear the override and revert to the compile-time default.
  static Future<void> reset([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(_endpointKey);
    _endpoint = bagistoEndpoint;
    debugPrint('🌐 ApiConfig.reset → $_endpoint');
  }

  /// Normalize user input into a full GraphQL endpoint URL.
  ///
  /// Handles common shorthands people type during testing:
  ///   `192.168.1.126:8001`            → `http://192.168.1.126:8001/graphql`
  ///   `http://192.168.1.126:8001`     → `http://192.168.1.126:8001/graphql`
  ///   `http://192.168.1.126:8001/`    → `http://192.168.1.126:8001/graphql`
  ///   `http://192.168.1.126:8001/graphql` → unchanged
  ///   `https://shop.example.com/graphql`  → unchanged
  static String normalize(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return bagistoEndpoint;

    // Add scheme if missing (default to http for local/LAN testing).
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }

    // Strip trailing slashes.
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }

    // Ensure it ends with /graphql (only append if not already present).
    if (!s.toLowerCase().endsWith('/graphql')) {
      s = '$s/graphql';
    }

    return s;
  }

  /// Basic validity check for the normalized endpoint (has host + http scheme).
  static bool isValid(String raw) {
    try {
      final uri = Uri.parse(normalize(raw));
      return uri.hasAuthority &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
