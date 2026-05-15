import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late EmailProtocol _protocol;
  late String _host;
  late String _port;
  late bool _useOAuth;
  late OAuthProvider _oauthProvider;
  late String _username;
  late String _password;
  late DateTime _startDate;
  late bool _deleteAfterRead;

  @override
  void initState() {
    super.initState();
    final config = context.read<AppState>().config;
    _protocol = config.protocol;
    _host = config.host;
    _port = config.port.toString();
    _useOAuth = config.useOAuth;
    _oauthProvider = config.oauthProvider;
    _username = config.username;
    _password = config.password;
    _startDate = config.startDate;
    _deleteAfterRead = config.deleteAfterRead;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    final config = EmailConfig(
      protocol: _protocol,
      host: _host,
      port: int.tryParse(_port) ?? 993,
      useOAuth: _useOAuth,
      oauthProvider: _oauthProvider,
      username: _username,
      password: _password,
      startDate: _startDate,
      deleteAfterRead: _deleteAfterRead,
    );

    context.read<AppState>().updateConfig(config);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuração salva')));
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );

    if (selected != null) {
      setState(() {
        _startDate = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<EmailProtocol>(
                value: _protocol,
                decoration: const InputDecoration(labelText: 'Protocolo de email'),
                items: EmailProtocol.values
                    .map((protocol) => DropdownMenuItem(value: protocol, child: Text(protocol.label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _protocol = value);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Usar OAuth'),
                value: _useOAuth,
                onChanged: (value) => setState(() => _useOAuth = value),
              ),
              if (_useOAuth) ...[
                DropdownButtonFormField<OAuthProvider>(
                  value: _oauthProvider,
                  decoration: const InputDecoration(labelText: 'Provedor OAuth'),
                  items: OAuthProvider.values
                      .map((provider) => DropdownMenuItem(value: provider, child: Text(provider.label)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _oauthProvider = value);
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('OAuth precisa ser configurado com o provedor real.'),
                    ));
                  },
                  child: const Text('Autorizar OAuth (placeholder)'),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _host,
                decoration: const InputDecoration(labelText: 'Servidor', hintText: 'imap.exemplo.com'),
                validator: (value) => value == null || value.isEmpty ? 'Informe o servidor' : null,
                onSaved: (value) => _host = value!.trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _port,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Porta', hintText: '993'),
                validator: (value) => value == null || value.isEmpty ? 'Informe a porta' : null,
                onSaved: (value) => _port = value!.trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _username,
                decoration: const InputDecoration(labelText: 'Usuário / E-mail'),
                validator: (value) => value == null || value.isEmpty ? 'Informe o usuário' : null,
                onSaved: (value) => _username = value!.trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _password,
                decoration: const InputDecoration(labelText: 'Senha / Token'),
                obscureText: true,
                onSaved: (value) => _password = value?.trim() ?? '',
              ),
              const SizedBox(height: 8),
              Text(
                _useOAuth && _oauthProvider == OAuthProvider.generic
                    ? 'Quando usar OAuth genérico, coloque aqui o token de acesso/refresh token fornecido pelo seu provedor.'
                    : 'Quando não usar OAuth, coloque aqui a senha da conta de email.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Ler a partir de'),
                subtitle: Text('${_startDate.toLocal()}'.split(' ')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickStartDate,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Excluir emails após leitura'),
                value: _deleteAfterRead,
                onChanged: (value) => setState(() => _deleteAfterRead = value),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Salvar configurações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
