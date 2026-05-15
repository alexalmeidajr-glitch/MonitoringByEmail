import 'package:flutter_appauth/flutter_appauth.dart';
import 'models.dart';

class OAuthService {
  static final FlutterAppAuth _appAuth = FlutterAppAuth();

  static const String _redirectUri = 'com.monitoringbyemail://oauthredirect';
  static const String _googleClientId = '<YOUR_GOOGLE_CLIENT_ID>'; // Substitua pelo seu clientId
  static const String _microsoftClientId = '<YOUR_MICROSOFT_CLIENT_ID>'; // Substitua pelo seu clientId

  static Future<String?> getAccessToken(EmailConfig config) async {
    if (!config.useOAuth) return null;
    if (config.oauthProvider == OAuthProvider.generic) {
      return config.password.isNotEmpty ? config.password : null;
    }

    final clientId = _clientIdFor(config.oauthProvider);
    final issuer = _issuerFor(config.oauthProvider);
    final scopes = _scopesFor(config.oauthProvider);

    if (clientId.isEmpty || issuer.isEmpty || scopes.isEmpty) {
      return null;
    }

    if (config.oauthRefreshToken.isNotEmpty) {
      final tokenResponse = await _appAuth.token(TokenRequest(
        clientId,
        _redirectUri,
        issuer: issuer,
        refreshToken: config.oauthRefreshToken,
        scopes: scopes,
      ));

      if (tokenResponse?.accessToken != null) {
        final updatedConfig = config.copyWith(oauthRefreshToken: tokenResponse?.refreshToken ?? config.oauthRefreshToken);
        await AppState.persistConfig(updatedConfig);
        return tokenResponse!.accessToken;
      }
    }

    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        _redirectUri,
        issuer: issuer,
        scopes: scopes,
        promptValues: ['consent'],
        loginHint: config.username.isNotEmpty ? config.username : null,
      ),
    );

    if (result?.accessToken != null) {
      final updatedConfig = config.copyWith(oauthRefreshToken: result?.refreshToken ?? config.oauthRefreshToken);
      await AppState.persistConfig(updatedConfig);
      return result!.accessToken;
    }

    return null;
  }

  static String _clientIdFor(OAuthProvider provider) {
    switch (provider) {
      case OAuthProvider.google:
        return _googleClientId;
      case OAuthProvider.microsoft:
        return _microsoftClientId;
      case OAuthProvider.generic:
        return '';
    }
  }

  static String _issuerFor(OAuthProvider provider) {
    switch (provider) {
      case OAuthProvider.google:
        return 'https://accounts.google.com';
      case OAuthProvider.microsoft:
        return 'https://login.microsoftonline.com/common/v2.0';
      case OAuthProvider.generic:
        return '';
    }
  }

  static List<String> _scopesFor(OAuthProvider provider) {
    switch (provider) {
      case OAuthProvider.google:
        return ['openid', 'email', 'profile', 'https://mail.google.com/'];
      case OAuthProvider.microsoft:
        return ['openid', 'offline_access', 'profile', 'email', 'https://outlook.office.com/IMAP.AccessAsUser.All'];
      case OAuthProvider.generic:
        return [];
    }
  }
}
