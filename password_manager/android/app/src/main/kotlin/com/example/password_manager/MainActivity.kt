package com.example.password_manager

import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    
    // Nombres de los canales
    private val CHANNEL_STORAGE = "com.example.password_manager/storage"
    private val CHANNEL_NAV = "com.example.password_manager/autofill_nav"

    // Variable temporal para guardar los datos que llegan desde el Autocompletado
    private var pendingNewEntry: Map<String, String>? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- 1. LÓGICA DE ALMACENAMIENTO (Tu código original) ---
        // Esto permite que Flutter guarde el JSON donde el Servicio Nativo pueda leerlo
        val repository = SecureRepository(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_STORAGE).setMethodCallHandler { call, result ->
            if (call.method == "saveVault") {
                val data = call.argument<String>("data")
                if (data != null) {
                    try {
                        repository.saveVault(data)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_DATA", "Data was null", null)
                }
            } else if (call.method == "getVault") {
                try {
                    val data = repository.getVault()
                    result.success(data)
                } catch (e: Exception) {
                    result.error("READ_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        // --- 2. LÓGICA DE NAVEGACIÓN (Lo nuevo para detectar "Guardar") ---
        // Esto permite que Flutter pregunte: "¿Me abriste para guardar una contraseña nueva?"
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAV).setMethodCallHandler { call, result ->
            if (call.method == "checkPendingEntry") {
                if (pendingNewEntry != null) {
                    // Si hay datos pendientes, se los enviamos a Flutter
                    result.success(pendingNewEntry)
                    pendingNewEntry = null // Limpiamos para no repetirlos
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // --- 3. CAPTURA DE INTENTS (Cuando Android abre tu app automáticamente) ---
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // En onCreate, Flutter aún NO está listo para recibir mensajes.
        // Solo guardamos los datos; Flutter los recogerá con checkPendingEntry.
        savePendingFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // En onNewIntent, Flutter YA está corriendo.
        // Guardamos los datos Y se los enviamos en tiempo real.
        savePendingFromIntent(intent)
        notifyFlutterIfReady()
    }

    private fun savePendingFromIntent(intent: Intent) {
        if (intent.action == "SAVE_NEW_PASSWORD") {
            val appName = intent.getStringExtra("app_name") ?: ""
            val packageId = intent.getStringExtra("package_id") ?: ""
            val username = intent.getStringExtra("username") ?: ""
            val password = intent.getStringExtra("password") ?: ""

            pendingNewEntry = mapOf(
                "app" to appName,
                "packageId" to packageId,
                "username" to username,
                "password" to password
            )
        }
    }

    private fun notifyFlutterIfReady() {
        val entry = pendingNewEntry ?: return
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL_NAV).invokeMethod("onPendingEntry", entry)
            pendingNewEntry = null
        }
    }
}