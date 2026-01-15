import 'package:nocodb/common/preferences.dart';

final directusSettings = _DirectusSettings();

class DirectusCredentials {
  DirectusCredentials({
    required this.host,
    required this.accessToken,
    this.refreshToken,
    required this.email,
  });

  final String host;
  final String accessToken;
  final String? refreshToken;
  final String email;
}

const _kDirectusHost = 'directus_host';
const _kDirectusAccessToken = 'directus_access_token';
const _kDirectusRefreshToken = 'directus_refresh_token';
const _kDirectusEmail = 'directus_email';

class _DirectusSettings {
  Preferences? prefs;
  bool get initialized => prefs != null;
  
  void init(Preferences prefs) {
    this.prefs = prefs;
  }

  Future<void> save({
    required String host,
    required String accessToken,
    String? refreshToken,
    required String email,
  }) async {
    await clear();
    await prefs?.set(key: _kDirectusHost, value: host);
    await prefs?.set(key: _kDirectusAccessToken, value: accessToken);
    if (refreshToken != null) {
      await prefs?.set(key: _kDirectusRefreshToken, value: refreshToken);
    }
    await prefs?.set(key: _kDirectusEmail, value: email);
  }

  Future<DirectusCredentials?> get() async {
    final host = await prefs?.get<String>(key: _kDirectusHost);
    final accessToken = await prefs?.get<String>(key: _kDirectusAccessToken);
    final refreshToken = await prefs?.get<String>(key: _kDirectusRefreshToken);
    final email = await prefs?.get<String>(key: _kDirectusEmail);

    if (host == null || accessToken == null || email == null) {
      return null;
    }

    return DirectusCredentials(
      host: host,
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
    );
  }

  Future<void> clear() async {
    await prefs?.set(key: _kDirectusHost, value: '');
    await prefs?.set(key: _kDirectusAccessToken, value: '');
    await prefs?.set(key: _kDirectusRefreshToken, value: '');
    await prefs?.set(key: _kDirectusEmail, value: '');
  }
}
