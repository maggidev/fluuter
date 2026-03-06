package com.example.whatsapp_bot_container

import io.flutter.embedding.android.FlutterActivity

/**
 * MainActivity — ponto de entrada do aplicativo Flutter no Android.
 *
 * A comunicação com o processo Node.js é feita via TCP Socket (porta 3001)
 * diretamente pelo código Dart, sem necessidade de MethodChannel nativo aqui.
 *
 * O Foreground Service é gerenciado pelo pacote flutter_foreground_task.
 */
class MainActivity : FlutterActivity()
