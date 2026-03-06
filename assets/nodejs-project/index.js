/**
 * WhatsApp Bot Container - Back-end Node.js
 * Biblioteca: @whiskeysockets/baileys
 * Comunicação com Flutter: TCP Socket (localhost:3001)
 * Autenticação: Pairing Code (sem QR Code)
 * Logger: Pino
 */

import makeWASocket, {
  DisconnectReason,
  useMultiFileAuthState,
  fetchLatestBaileysVersion,
  makeCacheableSignalKeyStore,
  isJidBroadcast,
} from '@whiskeysockets/baileys';
import pino from 'pino';
import net from 'net';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import NodeCache from 'node-cache';
import { downloadMediaMessage } from '@whiskeysockets/baileys';
import mime from 'mime-types';

// ─── Configurações de Caminho ──────────────────────────────────────────────
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const AUTH_FOLDER = path.join(__dirname, 'auth_info');
const MEDIA_FOLDER = path.join(__dirname, 'media');
const DELETED_MSGS_FILE = path.join(__dirname, 'deleted_messages.json');

// Garantir que as pastas existam
[AUTH_FOLDER, MEDIA_FOLDER].forEach((dir) => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

// ─── Logger Pino ──────────────────────────────────────────────────────────
const logger = pino({
  level: 'info',
  transport: {
    target: 'pino-pretty',
    options: {
      colorize: false,
      translateTime: 'SYS:HH:MM:ss',
      ignore: 'pid,hostname',
    },
  },
});

// ─── Cache de Mensagens (para detectar deleção) ───────────────────────────
const msgCache = new NodeCache({ stdTTL: 3600, checkperiod: 120 });

// ─── Armazenamento de Mensagens Apagadas ──────────────────────────────────
let deletedMessages = [];
try {
  if (fs.existsSync(DELETED_MSGS_FILE)) {
    deletedMessages = JSON.parse(fs.readFileSync(DELETED_MSGS_FILE, 'utf-8'));
  }
} catch (_) {
  deletedMessages = [];
}

function saveDeletedMessages() {
  fs.writeFileSync(DELETED_MSGS_FILE, JSON.stringify(deletedMessages, null, 2));
}

// ─── Servidor TCP para comunicação com Flutter ────────────────────────────
const TCP_PORT = 3001;
const clients = new Set();

const tcpServer = net.createServer((socket) => {
  logger.info(`[TCP] Flutter conectado: ${socket.remoteAddress}`);
  clients.add(socket);

  socket.on('data', (data) => {
    try {
      const cmd = JSON.parse(data.toString().trim());
      handleFlutterCommand(cmd);
    } catch (e) {
      logger.warn('[TCP] Comando inválido recebido do Flutter');
    }
  });

  socket.on('close', () => {
    clients.delete(socket);
    logger.info('[TCP] Flutter desconectado');
  });

  socket.on('error', (err) => {
    logger.error(`[TCP] Erro no socket: ${err.message}`);
    clients.delete(socket);
  });
});

tcpServer.listen(TCP_PORT, '127.0.0.1', () => {
  logger.info(`[TCP] Servidor escutando na porta ${TCP_PORT}`);
});

/**
 * Envia um evento JSON para todos os clientes Flutter conectados.
 * @param {string} type - Tipo do evento
 * @param {object} payload - Dados do evento
 */
function emitToFlutter(type, payload) {
  const message = JSON.stringify({ type, payload, timestamp: Date.now() }) + '\n';
  for (const client of clients) {
    try {
      client.write(message);
    } catch (e) {
      clients.delete(client);
    }
  }
  logger.info(`[EMIT] ${type}: ${JSON.stringify(payload).substring(0, 120)}`);
}

/**
 * Processa comandos recebidos do Flutter via TCP.
 * @param {object} cmd - Objeto de comando
 */
async function handleFlutterCommand(cmd) {
  if (cmd.action === 'get_pairing_code' && cmd.phone) {
    logger.info(`[CMD] Solicitação de Pairing Code para: ${cmd.phone}`);
    await requestPairingCode(cmd.phone);
  } else if (cmd.action === 'get_deleted_messages') {
    emitToFlutter('deleted_messages_list', { messages: deletedMessages });
  } else if (cmd.action === 'get_status') {
    emitToFlutter('connection_status', { status: currentStatus });
  }
}

// ─── Estado de Conexão ────────────────────────────────────────────────────
let currentStatus = 'disconnected';
let sock = null;
let pairingCodeRequested = false;

/**
 * Solicita o Pairing Code para o número de telefone informado.
 * O número deve estar no formato internacional sem '+' (ex: 5511999999999).
 * @param {string} phoneNumber
 */
async function requestPairingCode(phoneNumber) {
  if (!sock || !sock.authState) {
    logger.warn('[PAIRING] Socket não disponível ainda. Aguarde a inicialização.');
    return;
  }
  try {
    const code = await sock.requestPairingCode(phoneNumber);
    logger.info(`[PAIRING] Código gerado: ${code}`);
    emitToFlutter('pairing_code', { code, phone: phoneNumber });
  } catch (err) {
    logger.error(`[PAIRING] Erro ao gerar código: ${err.message}`);
    emitToFlutter('error', { message: `Erro ao gerar Pairing Code: ${err.message}` });
  }
}

// ─── Inicialização do Bot Baileys ─────────────────────────────────────────
async function startBot() {
  const { state, saveCreds } = await useMultiFileAuthState(AUTH_FOLDER);
  const { version } = await fetchLatestBaileysVersion();

  logger.info(`[BOT] Usando Baileys versão: ${version.join('.')}`);

  sock = makeWASocket({
    version,
    logger: pino({ level: 'silent' }), // Silencia logs internos do Baileys
    auth: {
      creds: state.creds,
      keys: makeCacheableSignalKeyStore(state.keys, pino({ level: 'silent' })),
    },
    printQRInTerminal: false, // Desabilita QR Code — usamos Pairing Code
    generateHighQualityLinkPreview: false,
    msgRetryCounterCache: new NodeCache(),
    getMessage: async (key) => {
      const cached = msgCache.get(key.id);
      return cached || undefined;
    },
  });

  // ── Evento: Atualização de Credenciais ──────────────────────────────────
  sock.ev.on('creds.update', saveCreds);

  // ── Evento: Atualização de Conexão ──────────────────────────────────────
  sock.ev.on('connection.update', async (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (connection === 'connecting') {
      currentStatus = 'connecting';
      emitToFlutter('connection_status', { status: 'connecting' });
      logger.info('[BOT] Conectando ao WhatsApp...');

      // Solicitar Pairing Code automaticamente se não autenticado
      if (!pairingCodeRequested && !sock.authState.creds.registered) {
        pairingCodeRequested = true;
        emitToFlutter('awaiting_phone', {
          message: 'Envie seu número de telefone para gerar o Pairing Code',
        });
      }
    }

    if (connection === 'open') {
      currentStatus = 'connected';
      pairingCodeRequested = false;
      const user = sock.user;
      emitToFlutter('connection_status', {
        status: 'connected',
        user: user?.name || user?.id || 'Desconhecido',
        phone: user?.id?.split(':')[0] || '',
      });
      logger.info(`[BOT] Conectado como: ${user?.name} (${user?.id})`);
    }

    if (connection === 'close') {
      const statusCode = lastDisconnect?.error?.output?.statusCode;
      const shouldReconnect = statusCode !== DisconnectReason.loggedOut;

      currentStatus = 'disconnected';
      emitToFlutter('connection_status', {
        status: 'disconnected',
        reason: lastDisconnect?.error?.message || 'Conexão encerrada',
        willReconnect: shouldReconnect,
      });

      logger.warn(`[BOT] Desconectado. Código: ${statusCode}. Reconectar: ${shouldReconnect}`);

      if (shouldReconnect) {
        setTimeout(() => {
          pairingCodeRequested = false;
          startBot();
        }, 5000);
      } else {
        logger.error('[BOT] Sessão encerrada (logout). Limpe a pasta auth_info para reconectar.');
        emitToFlutter('logged_out', { message: 'Sessão encerrada. Reconecte o dispositivo.' });
      }
    }
  });

  // ── Evento: Novas Mensagens ──────────────────────────────────────────────
  sock.ev.on('messages.upsert', async ({ messages, type }) => {
    if (type !== 'notify') return;

    for (const msg of messages) {
      if (!msg.message || isJidBroadcast(msg.key.remoteJid)) continue;

      const msgId = msg.key.id;
      const from = msg.key.remoteJid;
      const pushName = msg.pushName || 'Desconhecido';
      const timestamp = msg.messageTimestamp
        ? new Date(Number(msg.messageTimestamp) * 1000).toISOString()
        : new Date().toISOString();

      // Extrair texto da mensagem
      const textContent =
        msg.message?.conversation ||
        msg.message?.extendedTextMessage?.text ||
        msg.message?.imageMessage?.caption ||
        msg.message?.videoMessage?.caption ||
        null;

      // Armazenar no cache para detectar deleção futura
      msgCache.set(msgId, {
        id: msgId,
        from,
        pushName,
        text: textContent,
        timestamp,
        type: Object.keys(msg.message)[0],
      });

      // Emitir nova mensagem para o Flutter (opcional — para log em tempo real)
      emitToFlutter('new_message', {
        id: msgId,
        from,
        pushName,
        text: textContent,
        timestamp,
      });

      // ── Baixar mídia automaticamente ──────────────────────────────────
      const mediaTypes = ['imageMessage', 'videoMessage', 'audioMessage', 'documentMessage'];
      const mediaType = mediaTypes.find((t) => msg.message[t]);

      if (mediaType) {
        try {
          const buffer = await downloadMediaMessage(msg, 'buffer', {});
          const ext = mime.extension(msg.message[mediaType].mimetype) || 'bin';
          const filename = `${msgId}.${ext}`;
          const filePath = path.join(MEDIA_FOLDER, filename);
          fs.writeFileSync(filePath, buffer);

          emitToFlutter('media_saved', {
            id: msgId,
            from,
            pushName,
            filePath,
            mediaType,
            timestamp,
          });

          logger.info(`[MEDIA] Salvo: ${filename}`);
        } catch (err) {
          logger.error(`[MEDIA] Erro ao baixar mídia: ${err.message}`);
        }
      }
    }
  });

  // ── Evento: Atualização de Mensagens (Detectar Deleção) ─────────────────
  sock.ev.on('messages.update', (updates) => {
    for (const update of updates) {
      const { key, update: msgUpdate } = update;

      // Verifica se a mensagem foi apagada (protocolMessage de revogação)
      if (
        msgUpdate?.message?.protocolMessage?.type === 0 || // REVOKE
        msgUpdate?.message?.protocolMessage?.type === 5    // EPHEMERAL_SETTING
      ) {
        const deletedId = msgUpdate?.message?.protocolMessage?.key?.id || key.id;
        const cached = msgCache.get(deletedId);

        if (cached) {
          const deletedEntry = {
            ...cached,
            deletedAt: new Date().toISOString(),
          };

          deletedMessages.unshift(deletedEntry); // Mais recente primeiro
          if (deletedMessages.length > 500) deletedMessages.pop(); // Limite de 500
          saveDeletedMessages();

          emitToFlutter('message_deleted', deletedEntry);
          logger.info(`[DELETE] Mensagem apagada de ${cached.pushName}: "${cached.text}"`);
        } else {
          // Mensagem não estava no cache (chegou antes do bot iniciar)
          const unknownEntry = {
            id: deletedId,
            from: key.remoteJid,
            pushName: 'Desconhecido',
            text: '[Mensagem não disponível — apagada antes de ser capturada]',
            timestamp: new Date().toISOString(),
            deletedAt: new Date().toISOString(),
          };
          deletedMessages.unshift(unknownEntry);
          saveDeletedMessages();
          emitToFlutter('message_deleted', unknownEntry);
        }
      }
    }
  });

  logger.info('[BOT] Bot inicializado. Aguardando conexão...');
}

// ─── Iniciar ──────────────────────────────────────────────────────────────
startBot().catch((err) => {
  logger.error(`[FATAL] Erro crítico ao iniciar o bot: ${err.message}`);
  process.exit(1);
});

// ─── Graceful Shutdown ────────────────────────────────────────────────────
process.on('SIGTERM', () => {
  logger.info('[BOT] Encerrando graciosamente...');
  tcpServer.close();
  process.exit(0);
});
