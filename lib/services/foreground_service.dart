import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Serviço responsável por iniciar e gerenciar o Foreground Service no Android.
/// Isso impede que o sistema operacional mate o processo Node.js em segundo plano.
class ForegroundServiceManager {
  static bool _initialized = false;

  /// Inicializa o Foreground Task com as configurações de notificação.
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'whatsapp_bot_service',
        channelName: 'WhatsApp Bot Service',
        channelDescription: 'Mantém o bot do WhatsApp ativo em segundo plano.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _initialized = true;
  }

  /// Solicita permissão de notificação (Android 13+) e inicia o serviço.
  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    if (!_initialized) await initialize();

    // Solicitar permissão de notificação
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Ativar WakeLock para impedir que a CPU durma
    await WakelockPlus.enable();

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'WhatsApp Bot Ativo',
        notificationText: 'O bot está monitorando mensagens em segundo plano.',
        callback: startCallback,
      );
    }
  }

  /// Para o Foreground Service.
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    await WakelockPlus.disable();
    await FlutterForegroundTask.stopService();
  }

  /// Atualiza o texto da notificação do Foreground Service.
  static Future<void> updateNotification(String status) async {
    if (!Platform.isAndroid) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'WhatsApp Bot',
      notificationText: status,
    );
  }
}

/// Callback executado pelo Foreground Service em segundo plano.
/// DEVE ser uma função de nível superior (não pode ser método de classe).
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(BotTaskHandler());
}

/// Handler do Foreground Task — executado periodicamente em segundo plano.
class BotTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[ForegroundTask] Serviço iniciado em: $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Evento periódico a cada 5 segundos — pode ser usado para health check
    debugPrint('[ForegroundTask] Heartbeat: $timestamp');
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[ForegroundTask] Serviço encerrado em: $timestamp');
  }
}
