import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:imap_client/imap_client.dart';
import 'package:pop3_client/pop3_client.dart';

import 'models.dart';
import 'oauth_service.dart';

class EmailMessage {
  final String id;
  final String subject;
  final String body;
  final DateTime receivedAt;

  EmailMessage({
    required this.id,
    required this.subject,
    required this.body,
    required this.receivedAt,
  });
}

class EmailService {
  static const String expectedPrefix = 'Monitoring My Email - ';

  static Future<List<EmailMessage>> fetchMessages(EmailConfig config) async {
    if (config.host.isEmpty || config.username.isEmpty) {
      return [];
    }

    final authToken = config.useOAuth ? await OAuthService.getAccessToken(config) : null;
    if (config.useOAuth && authToken == null) {
      return [];
    }

    if (config.protocol == EmailProtocol.pop3) {
      return await _fetchPop3Messages(config, authToken);
    }

    return await _fetchImapMessages(config, authToken);
  }

  static bool subjectMatches(String subject) {
    return subject.startsWith(expectedPrefix);
  }

  static String? extractTabName(String subject) {
    if (!subjectMatches(subject)) {
      return null;
    }

    final remainder = subject.substring(expectedPrefix.length);
    final firstDash = remainder.indexOf('-');
    if (firstDash <= 0) {
      return remainder.trim();
    }
    return remainder.substring(0, firstDash).trim();
  }

  static EmailTab parseEmailToTab(EmailMessage message) {
    final tabName = extractTabName(message.subject) ?? 'Sem aba';
    final body = message.body.trim();
    String content = body;
    bool isHtml = false;
    String? rawJson;

    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic> && parsed.containsKey('HTML')) {
        content = parsed['HTML']?.toString() ?? body;
        isHtml = true;
        rawJson = jsonEncode(parsed);
      } else {
        rawJson = const JsonEncoder.withIndent('  ').convert(parsed);
        content = rawJson;
      }
    } catch (_) {
      content = body;
    }

    return EmailTab(
      name: tabName,
      content: content,
      isHtml: isHtml,
      rawJson: rawJson,
      updatedAt: message.receivedAt,
    );
  }

  static Future<void> deleteEmail(EmailConfig config, EmailMessage message) async {
    if (config.protocol == EmailProtocol.pop3) {
      return;
    }

    final client = ImapClient(
      host: config.host,
      port: config.port,
      isSecure: config.port == 993,
    );

    try {
      await client.connect();
      if (config.useOAuth) {
        final authToken = await OAuthService.getAccessToken(config);
        if (authToken != null) {
          await client.authenticateXOAuth2(config.username, authToken);
        }
      } else {
        await client.login(config.username, config.password);
      }
      await client.selectInbox();
      await client.deleteEmail(message.id);
    } finally {
      await client.logout();
    }
  }

  static Future<List<EmailMessage>> _fetchImapMessages(EmailConfig config, String? authToken) async {
    final client = ImapClient(
      host: config.host,
      port: config.port,
      isSecure: config.port == 993,
    );

    try {
      await client.connect();
      if (config.useOAuth && authToken != null) {
        await client.authenticateXOAuth2(config.username, authToken);
      } else {
        await client.login(config.username, config.password);
      }

      await client.selectInbox();
      final uids = await client.search('SINCE ${_imapDate(config.startDate)}');
      final messages = <EmailMessage>[];

      for (final uid in uids) {
        final raw = await client.fetchMessage(uid);
        final subject = _extractHeaderValue(raw, 'Subject') ?? '';
        final body = _extractBody(raw);
        final receivedAt = DateTime.now();

        if (!subjectMatches(subject)) {
          continue;
        }

        final id = '$uid-${receivedAt.millisecondsSinceEpoch}';
        messages.add(EmailMessage(id: id, subject: subject, body: body, receivedAt: receivedAt));
      }

      if (config.deleteAfterRead) {
        for (final message in messages) {
          await client.deleteEmail(message.id);
        }
      }

      return messages;
    } finally {
      await client.logout();
    }
  }

  static Future<List<EmailMessage>> _fetchPop3Messages(EmailConfig config, String? authToken) async {
    final client = Pop3Client(
      host: config.host,
      port: config.port,
      useSsl: config.port == 995,
    );

    try {
      await client.connect();
      if (config.useOAuth && authToken != null) {
        await client.authenticateXOAuth2(config.username, authToken);
      } else {
        await client.login(config.username, config.password);
      }

      final uids = await client.list();
      final messages = <EmailMessage>[];

      for (final uid in uids) {
        final raw = await client.retr(uid.number);
        final subject = _extractHeaderValue(raw, 'Subject') ?? '';
        final body = _extractBody(raw);
        final dateHeader = _extractHeaderValue(raw, 'Date');
        final receivedAt = dateHeader != null ? DateTime.tryParse(dateHeader) ?? DateTime.now() : DateTime.now();

        if (!subjectMatches(subject)) {
          continue;
        }

        final id = '${uid.number}-${receivedAt.millisecondsSinceEpoch}';
        messages.add(EmailMessage(id: id, subject: subject, body: body, receivedAt: receivedAt));

        if (config.deleteAfterRead) {
          await client.dele(uid.number);
        }
      }

      if (config.deleteAfterRead) {
        await client.quit(deleteMessages: true);
      } else {
        await client.quit();
      }

      return messages;
    } finally {
      if (!client.isClosed) {
        await client.quit();
      }
    }
  }

  static String _imapDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day-$month-$year';
  }

  static String _extractBody(String raw) {
    final separator = '\r\n\r\n';
    final index = raw.indexOf(separator);
    if (index < 0) {
      return raw.trim();
    }
    return raw.substring(index + separator.length).trim();
  }

  static String? _extractHeaderValue(String raw, String headerName) {
    final regex = RegExp('^$headerName:\s*(.+)\$', multiLine: true, caseSensitive: false);
    final match = regex.firstMatch(raw);
    return match?.group(1)?.trim();
  }
}

class BackgroundEmailPoller {
  static Future<void> poll(EmailConfig config) async {
    final messages = await EmailService.fetchMessages(config);
    if (messages.isEmpty) {
      return;
    }

    final state = await AppState.load();
    var changed = false;

    for (final message in messages) {
      final tab = EmailService.parseEmailToTab(message);
      final existing = state.tabs.where((existingTab) => existingTab.name == tab.name).toList();
      if (existing.isEmpty || existing.first.content != tab.content) {
        state.addOrUpdateTab(tab);
        changed = true;
        await NotificationService.showNotification(
          'Nova atualização: ${tab.name}',
          'Conteúdo atualizado para a aba ${tab.name}.',
        );
      }
    }

    if (changed) {
      state.updateLastSync(DateTime.now());
    }
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'monitoring_by_email_channel',
    'Monitoramento de Email',
    description: 'Notificações de atualizações de abas do MonitoringByEmail',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await plugin.initialize(initializationSettings);
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  static Future<void> showNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await plugin.show(title.hashCode, title, body, details);
  }
}
