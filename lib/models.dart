import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EmailProtocol { imap, pop3, exchange }
enum OAuthProvider { google, microsoft, generic }

extension EmailProtocolExtension on EmailProtocol {
  String get label {
    switch (this) {
      case EmailProtocol.imap:
        return 'IMAP';
      case EmailProtocol.pop3:
        return 'POP3';
      case EmailProtocol.exchange:
        return 'Exchange';
    }
  }
}

extension OAuthProviderExtension on OAuthProvider {
  String get label {
    switch (this) {
      case OAuthProvider.google:
        return 'Google';
      case OAuthProvider.microsoft:
        return 'Microsoft';
      case OAuthProvider.generic:
        return 'Genérico';
    }
  }
}

class EmailConfig {
  final EmailProtocol protocol;
  final String host;
  final int port;
  final bool useOAuth;
  final OAuthProvider oauthProvider;
  final String username;
  final String password;
  final String oauthRefreshToken;
  final DateTime startDate;
  final bool deleteAfterRead;

  EmailConfig({
    required this.protocol,
    required this.host,
    required this.port,
    required this.useOAuth,
    required this.oauthProvider,
    required this.username,
    required this.password,
    required this.startDate,
    required this.deleteAfterRead,
  });

  factory EmailConfig.defaults() {
    return EmailConfig(
      protocol: EmailProtocol.imap,
      host: '',
      port: 993,
      useOAuth: false,
      oauthProvider: OAuthProvider.generic,
      username: '',
      password: '',
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      deleteAfterRead: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol.name,
      'host': host,
      'port': port,
      'useOAuth': useOAuth,
      'oauthProvider': oauthProvider.name,
      'username': username,
      'password': password,
      'oauthRefreshToken': oauthRefreshToken,
      'startDate': startDate.toIso8601String(),
      'deleteAfterRead': deleteAfterRead,
    };
  }

  factory EmailConfig.fromJson(Map<String, dynamic> json) {
    return EmailConfig(
      protocol: EmailProtocol.values.firstWhere((element) => element.name == json['protocol'], orElse: () => EmailProtocol.imap),
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 993,
      useOAuth: json['useOAuth'] as bool? ?? false,
      oauthProvider: OAuthProvider.values.firstWhere((element) => element.name == json['oauthProvider'], orElse: () => OAuthProvider.generic),
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now().subtract(const Duration(days: 1)),
      oauthRefreshToken: json['oauthRefreshToken'] as String? ?? '',
      deleteAfterRead: json['deleteAfterRead'] as bool? ?? false,
    );
  }

  EmailConfig copyWith({
    EmailProtocol? protocol,
    String? host,
    int? port,
    bool? useOAuth,
    OAuthProvider? oauthProvider,
    String? username,
    String? password,
    String? oauthRefreshToken,
    DateTime? startDate,
    bool? deleteAfterRead,
  }) {
    return EmailConfig(
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      port: port ?? this.port,
      useOAuth: useOAuth ?? this.useOAuth,
      oauthProvider: oauthProvider ?? this.oauthProvider,
      username: username ?? this.username,
      password: password ?? this.password,
      oauthRefreshToken: oauthRefreshToken ?? this.oauthRefreshToken,
      startDate: startDate ?? this.startDate,
      deleteAfterRead: deleteAfterRead ?? this.deleteAfterRead,
    );
  }
}

class EmailTab {
  final String name;
  final String content;
  final bool isHtml;
  final String? rawJson;
  final DateTime updatedAt;

  EmailTab({
    required this.name,
    required this.content,
    required this.isHtml,
    required this.updatedAt,
    this.rawJson,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'content': content,
      'isHtml': isHtml,
      'rawJson': rawJson,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EmailTab.fromJson(Map<String, dynamic> json) {
    return EmailTab(
      name: json['name'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isHtml: json['isHtml'] as bool? ?? false,
      rawJson: json['rawJson'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AppState extends ChangeNotifier {
  EmailConfig config;
  final List<EmailTab> tabs;
  int selectedIndex;
  DateTime lastSync;

  AppState({
    required this.config,
    required this.tabs,
    required this.selectedIndex,
    required this.lastSync,
  });

  factory AppState.initial() {
    return AppState(
      config: EmailConfig.defaults(),
      tabs: [],
      selectedIndex: 0,
      lastSync: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static const String _configKey = 'email_config';
  static const String _tabsKey = 'email_tabs';
  static const String _lastSyncKey = 'last_sync';

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final configData = prefs.getString(_configKey);
    final tabsData = prefs.getString(_tabsKey);
    final lastSyncString = prefs.getString(_lastSyncKey);

    final config = configData != null
        ? EmailConfig.fromJson(jsonDecode(configData) as Map<String, dynamic>)
        : EmailConfig.defaults();

    final tabs = <EmailTab>[];
    if (tabsData != null) {
      final stored = jsonDecode(tabsData) as List<dynamic>;
      for (final raw in stored) {
        tabs.add(EmailTab.fromJson(raw as Map<String, dynamic>));
      }
    }

    final lastSync = DateTime.tryParse(lastSyncString ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

    return AppState(config: config, tabs: tabs, selectedIndex: 0, lastSync: lastSync);
  }

  static Future<EmailConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configData = prefs.getString(_configKey);
    if (configData == null) return null;
    return EmailConfig.fromJson(jsonDecode(configData) as Map<String, dynamic>);
  }

  static Future<void> persistConfig(EmailConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
    await prefs.setString(_tabsKey, jsonEncode(tabs.map((tab) => tab.toJson()).toList()));
    await prefs.setString(_lastSyncKey, lastSync.toIso8601String());
  }

  void updateConfig(EmailConfig newConfig) {
    config = newConfig;
    notifyListeners();
    save();
  }

  void addOrUpdateTab(EmailTab tab) {
    final index = tabs.indexWhere((existing) => existing.name == tab.name);
    if (index >= 0) {
      tabs[index] = tab;
      selectedIndex = index;
    } else {
      tabs.add(tab);
      selectedIndex = tabs.length - 1;
    }
    notifyListeners();
    save();
  }

  void updateLastSync(DateTime date) {
    lastSync = date;
    notifyListeners();
    save();
  }
}
