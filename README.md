# MonitoringByEmail

App Flutter para monitoramento de processos por email.

## Objetivo
O aplicativo lê emails da caixa de entrada e cria abas baseadas no subject. Cada aba atualiza o conteúdo com o último email recebido cujo assunto começa com:

`Monitoring My Email - <nome-da-aba> - ...`

## Funcionalidades
- Configuração de servidor de email e protocolo (IMAP, POP3, Exchange)
- Suporte para OAuth e autenticação tradicional
- Data inicial de leitura configurável
- Exclusão opcional de emails após leitura
- Abas dinâmicas para cada assunto válido
- Renderização de HTML quando o JSON contém `HTML`
- Exibição de texto simples ou JSON bruto
- Background polling para checagem periódica de emails
- Verificação ativa a cada 5 minutos enquanto o app estiver aberto
- Notificações locais quando há novo conteúdo na aba

## Estrutura do projeto
- `pubspec.yaml` - dependências Flutter
- `lib/main.dart` - ponto de entrada e agendamento de background
- `lib/models.dart` - classes de dados e helpers
- `lib/email_service.dart` - lógica de leitura e parsing de email
- `lib/screens/config_screen.dart` - tela de configuração
- `lib/screens/home_screen.dart` - tela principal com abas
- `lib/screens/tab_view.dart` - renderização do conteúdo

## Observações
Este repositório contém a implementação do app. Para compilar e rodar, é necessário o SDK Flutter instalado.

Após instalar o Flutter, use:

```bash
cd MonitoringByEmail
flutter pub get
flutter run
```

## Nota
A leitura de email em ambientes reais requer integração com provedores de email e OAuth específicos. O código já está preparado para suportar IMAP/POP3/Exchange com OAuth, mas é necessário configurar os client IDs e o redirect URI nas plataformas mobile.

### Configuração OAuth
- Preencha `lib/oauth_service.dart` com seus `clientId` do Google e Microsoft.
- Use o redirect URI `com.monitoringbyemail://oauthredirect` ou altere o valor para o callback registrado no provedor.
- No Android, edite `android/app/src/main/AndroidManifest.xml` e adicione o filtro de intent para o mesmo scheme e host do redirect URI.
- No iOS, edite `ios/Runner/Info.plist` e adicione o URL type com o mesmo scheme usado no redirect URI.

#### Exemplo Android
O arquivo `android/app/src/main/AndroidManifest.xml` já inclui:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data
    android:scheme="com.monitoringbyemail"
    android:host="oauthredirect" />
</intent-filter>
```

#### Exemplo iOS
O arquivo `ios/Runner/Info.plist` já inclui:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>com.monitoringbyemail.app</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.monitoringbyemail</string>
    </array>
  </dict>
</array>
```

### Observações
- O app usa refresh token persistente para polling em background.
- A opção `Genérico` usa o valor de token informado no campo `Senha`.
- Se você alterar o redirect URI no OAuth provider, mantenha os mesmos valores em `oauth_service.dart`, AndroidManifest e Info.plist.
