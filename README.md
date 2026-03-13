# WhatsApp Bot Container

**Flutter + Baileys (Node.js) — Bot de WhatsApp com Interface Nativa**

Este projeto implementa um aplicativo Android/iOS que funciona como container para rodar a biblioteca [Baileys](https://github.com/WhiskeySockets/Baileys) (Node.js) internamente, com uma interface Flutter moderna para exibir logs, mensagens apagadas e mídias capturadas.

---

## Arquitetura do Sistema

```
┌─────────────────────────────────────────────────────────┐
│                    FLUTTER (UI)                         │
│  ┌──────────┐  ┌───────────────┐  ┌──────────────────┐ │
│  │Dashboard │  │Msgs Apagadas  │  │Galeria de Mídias │ │
│  └──────────┘  └───────────────┘  └──────────────────┘ │
│                        │                                │
│              NodeService (TCP Client)                   │
│                        │ TCP :3001                      │
└────────────────────────┼────────────────────────────────┘
                         │
┌────────────────────────┼────────────────────────────────┐
│              NODE.JS (Baileys Back-end)                 │
│                        │                                │
│   TCP Server :3001 ◄───┘                                │
│         │                                               │
│   @whiskeysockets/baileys                               │
│         │                                               │
│   WhatsApp Web Protocol (WebSocket)                     │
└─────────────────────────────────────────────────────────┘
```

### Fluxo de Comunicação

| Direção | Protocolo | Porta | Formato |
|---------|-----------|-------|---------|
| Flutter → Node.js | TCP Socket | 3001 | JSON + `\n` |
| Node.js → Flutter | TCP Socket | 3001 | JSON + `\n` |
| Node.js → WhatsApp | WebSocket (Baileys) | 443 | Protocolo WA |

### Tipos de Eventos (Node.js → Flutter)

| Tipo | Descrição |
|------|-----------|
| `connection_status` | Status da conexão: `connecting`, `connected`, `disconnected` |
| `pairing_code` | Código de 8 dígitos para emparelhamento |
| `awaiting_phone` | Solicita número de telefone ao usuário |
| `message_deleted` | Dados da mensagem apagada capturada |
| `media_saved` | Caminho do arquivo de mídia salvo |
| `new_message` | Nova mensagem recebida (para cache) |
| `logged_out` | Sessão encerrada pelo WhatsApp |
| `error` | Erro genérico com mensagem descritiva |

---

## Estrutura de Arquivos

```
whatsapp_bot_container/
├── lib/
│   ├── main.dart                          # Ponto de entrada Flutter
│   ├── models/
│   │   ├── deleted_message.dart           # Modelo de mensagem apagada
│   │   └── media_item.dart                # Modelo de mídia capturada
│   ├── database/
│   │   └── database_helper.dart           # SQFlite — persistência local
│   ├── services/
│   │   ├── node_service.dart              # Cliente TCP + gerenciamento de estado
│   │   └── foreground_service.dart        # Foreground Service Android
│   ├── screens/
│   │   ├── home_screen.dart               # Dashboard + navegação
│   │   ├── deleted_messages_screen.dart   # Lista de mensagens apagadas
│   │   ├── gallery_screen.dart            # Galeria de mídias
│   │   └── logs_screen.dart               # Console de logs em tempo real
│   └── widgets/
│       └── connection_card.dart           # Card de conexão e Pairing Code
├── assets/
│   └── nodejs-project/
│       ├── index.js                       # Bot Baileys principal
│       ├── package.json                   # Dependências Node.js
│       └── .npmrc                         # Configuração npm
├── android/
│   ├── app/
│   │   ├── build.gradle                   # Configuração do módulo app
│   │   └── src/main/
│   │       ├── AndroidManifest.xml        # Permissões e serviços
│   │       └── kotlin/.../MainActivity.kt
│   ├── build.gradle                       # Configuração raiz Android
│   ├── settings.gradle
│   ├── gradle.properties
│   ├── gradlew                            # Wrapper Gradle (Linux/macOS)
│   ├── gradlew.bat                        # Wrapper Gradle (Windows)
│   └── gradle/wrapper/gradle-wrapper.properties # Configuração do wrapper
├── ios/
│   ├── Runner.xcodeproj/
│   │   ├── project.pbxproj                # Configuração do projeto Xcode
│   │   └── project.xcworkspace/           # Workspace do Xcode
│   │       └── contents.xcworkspacedata
│   └── Runner/
│       ├── AppDelegate.swift              # Delegate principal do iOS
│       ├── main.m                         # Ponto de entrada Objective-C
│       ├── Info.plist                     # Permissões iOS
│       ├── Base.lproj/LaunchScreen.storyboard # Tela de splash
│       └── Assets.xcassets/               # Assets de imagem
├── pubspec.yaml                           # Dependências Flutter
└── README.md                              # Este arquivo
```

---

## Pré-requisitos

### Ferramentas Necessárias

| Ferramenta | Versão Mínima | Download |
|------------|---------------|----------|
| Flutter SDK | 3.22.0+ | [flutter.dev](https://flutter.dev) |
| Dart SDK | 3.3.0+ | Incluído no Flutter |
| Node.js | 18.0.0+ | [nodejs.org](https://nodejs.org) |
| Android Studio | Hedgehog+ | Para build Android |
| Xcode | 15.0+ | Para build iOS (macOS) |

---

## Configuração e Build

### Passo 1 — Instalar dependências Node.js

```bash
cd assets/nodejs-project
npm install
```

### Passo 2 — Instalar dependências Flutter

```bash
flutter pub get
```

### Passo 3 — Build Android (APK)

> **Importante:** Evite usar `flutter build appbundle --debug`. O `appbundle` é para produção (`--release`), e o `--debug` pode causar conflitos. Para depuração ou testes, use `apk`.

```bash
# APK de debug (para testes e depuração detalhada)
flutter build apk --debug -v # O -v (verbose) mostra logs detalhados do Gradle

# APK de release (para distribuição)
flutter build apk --release --split-per-abi

# APK universal (um único arquivo)
flutter build apk --release
```

O APK gerado estará em: `build/app/outputs/flutter-apk/`

### Passo 4 — Build iOS (IPA)

> **Requer macOS com Xcode instalado.**

```bash
# Instalar pods iOS
cd ios && pod install && cd ..

# Build de release
flutter build ipa --release
```

O IPA gerado estará em: `build/ios/ipa/`

---

## Build em Nuvem (Sem PC Potente)

### Opção A — Codemagic (Recomendado)

O [Codemagic](https://codemagic.io) oferece **500 minutos gratuitos/mês** para builds Flutter.

**Passos:**
1. Faça upload do projeto para um repositório GitHub/GitLab/Bitbucket.
2. Acesse [codemagic.io](https://codemagic.io) e conecte seu repositório.
3. Selecione **Flutter App** como tipo de projeto.
4. Configure as variáveis de ambiente se necessário.
5. Inicie o build — o Codemagic detecta automaticamente o `pubspec.yaml`.

**Arquivo `codemagic.yaml` (opcional, para configuração avançada):**

```yaml
workflows:
  android-workflow:
    name: Android Release
    environment:
      flutter: 3.22.0
      java: 17
    scripts:
      - name: Instalar dependências Node.js
        script: cd assets/nodejs-project && npm install
      - name: Flutter pub get
        script: flutter pub get
      - name: Build APK
        script: flutter build apk --release
    artifacts:
      - build/app/outputs/flutter-apk/*.apk
```

### Opção B — Appcircle

O [Appcircle](https://appcircle.io) também oferece plano gratuito para builds Flutter.

**Passos:**
1. Conecte seu repositório Git ao Appcircle.
2. Crie um novo **Build Profile** do tipo Flutter.
3. Configure o workflow para executar `npm install` antes do `flutter build`.
4. Inicie o build e baixe o APK/IPA gerado.

### Opção C — GitHub Actions (Gratuito para repositórios públicos)

Crie o arquivo `.github/workflows/build.yml`:

```yaml
name: Build Flutter APK

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Instalar dependências Node.js
        run: cd assets/nodejs-project && npm install
      - name: Flutter pub get
        run: flutter pub get
      - name: Build APK
        run: flutter build apk --release
      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

---

## Como Usar o Aplicativo

### Primeira Conexão (Pairing Code)

1. Abra o aplicativo no Android/iOS.
2. Na tela **Dashboard**, localize o card **"WhatsApp Bot"**.
3. Digite seu número de telefone no formato internacional **sem o `+`** (exemplo: `5511999999999`).
4. Toque em **"Gerar Código"** e aguarde alguns segundos.
5. Um código de **8 dígitos** será exibido na tela.
6. No WhatsApp do seu celular, acesse: **Configurações → Dispositivos Vinculados → Vincular com número de telefone**.
7. Digite o código exibido no app.
8. A conexão será estabelecida automaticamente.

### Verificação do Pairing Code

O código gerado segue o padrão `XXXX-XXXX` (8 caracteres alfanuméricos). Confira se o código exibido no app corresponde exatamente ao solicitado pelo WhatsApp. O código expira em **aproximadamente 60 segundos** — se expirar, toque novamente em "Gerar Código".

```javascript
// Trecho do index.js que gera o Pairing Code
const code = await sock.requestPairingCode(phoneNumber);
// phoneNumber: '5511999999999' (sem +, sem espaços, sem traços)
// code: 'ABCD1234' (retornado pelo Baileys)
```

---

## Detecção de Mensagens Apagadas

O bot detecta mensagens apagadas interceptando o evento `messages.update` do Baileys. Quando uma mensagem é apagada, o WhatsApp envia um `protocolMessage` do tipo `REVOKE` (tipo 0).

```javascript
// Lógica de detecção no index.js
sock.ev.on('messages.update', (updates) => {
  for (const update of updates) {
    if (update.update?.message?.protocolMessage?.type === 0) {
      // Mensagem foi apagada — recuperar do cache
      const cached = msgCache.get(deletedId);
      // Emitir para o Flutter via TCP
      emitToFlutter('message_deleted', cached);
    }
  }
});
```

> **Limitação importante:** O bot só consegue recuperar o conteúdo de mensagens que chegaram **enquanto o bot estava ativo e conectado**. Mensagens anteriores à conexão do bot não ficam disponíveis.

---

## Permissões Android

| Permissão | Finalidade |
|-----------|-----------|
| `INTERNET` | Conexão do Baileys com os servidores do WhatsApp |
| `WAKE_LOCK` | Impede que a CPU durma e mate o processo Node.js |
| `FOREGROUND_SERVICE` | Mantém o bot ativo em segundo plano |
| `READ/WRITE_EXTERNAL_STORAGE` | Salvar mídias capturadas (Android ≤ 12) |
| `READ_MEDIA_IMAGES/VIDEO/AUDIO` | Salvar mídias capturadas (Android 13+) |
| `POST_NOTIFICATIONS` | Exibir notificação do Foreground Service |
| `RECEIVE_BOOT_COMPLETED` | Reiniciar o bot após reboot do dispositivo |

---

## Dependências Principais

### Flutter (pubspec.yaml)

| Pacote | Versão | Finalidade |
|--------|--------|-----------|
| `provider` | ^6.1.2 | Gerenciamento de estado |
| `sqflite` | ^2.3.3+1 | Banco de dados local SQLite |
| `flutter_foreground_task` | ^9.2.1 | Foreground Service Android |
| `wakelock_plus` | ^1.4.0 | Manter CPU ativa |
| `permission_handler` | ^12.0.1 | Permissões em runtime |
| `path_provider` | ^2.1.4 | Caminhos de arquivo |

### Node.js (package.json)

| Pacote | Versão | Finalidade |
|--------|--------|-----------|
| `@whiskeysockets/baileys` | ^6.7.9 | Biblioteca WhatsApp Web |
| `pino` | ^9.4.0 | Logger de alta performance |
| `node-cache` | ^5.1.2 | Cache em memória para mensagens |
| `mime-types` | ^2.1.35 | Detectar extensão de arquivos de mídia |
| `fs-extra` | ^11.2.0 | Utilitários de sistema de arquivos |

---

## Aviso Legal

Este projeto é desenvolvido para fins educacionais e de pesquisa. O uso de bots no WhatsApp pode violar os [Termos de Serviço do WhatsApp](https://www.whatsapp.com/legal/terms-of-service). O desenvolvedor é responsável pelo uso que faz desta ferramenta. Use com responsabilidade.

---

*Gerado por Manus AI — Estrutura de código completa para compilação via Codemagic/Appcircle.*
