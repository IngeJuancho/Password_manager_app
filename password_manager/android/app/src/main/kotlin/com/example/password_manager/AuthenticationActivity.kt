package com.example.password_manager

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.autofill.Dataset
import android.util.Log
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import java.util.concurrent.Executor

@RequiresApi(Build.VERSION_CODES.O)
class AuthenticationActivity : FragmentActivity() {

    private lateinit var executor: Executor
    private lateinit var biometricPrompt: BiometricPrompt
    private lateinit var promptInfo: BiometricPrompt.PromptInfo

    companion object {
        private const val TAG = "🔐AuthActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // --- UX MEJORADA: Transición suave de entrada ---
        @Suppress("DEPRECATION")
        overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
        
        Log.d(TAG, "🔐 Activity de autenticación iniciada")
        
        // 1. Configurar biometría
        setupBiometricAuthentication()
        
        // 2. Iniciar autenticación inmediatamente
        authenticateUser()
    }

    // --- UX MEJORADA: Transición suave de salida ---
    override fun finish() {
        super.finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(android.R.anim.fade_in, android.R.anim.fade_out)
    }

    private fun setupBiometricAuthentication() {
        executor = ContextCompat.getMainExecutor(this)
        
        biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    Log.e(TAG, "❌ Error de autenticación: $errString")
                    
                    // Si falla o cancela, cerramos la activity sin resultado OK
                    setResult(RESULT_CANCELED)
                    finish()
                }

                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    Log.d(TAG, "✅ Autenticación exitosa")
                    
                    // 3. Si la huella es correcta, construimos el Dataset
                    onAuthenticationSuccess()
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    Toast.makeText(applicationContext, "Huella no reconocida. Intenta de nuevo.", Toast.LENGTH_SHORT).show()
                }
            })

        val appName = intent.getStringExtra("app_name") ?: "la aplicación"
        
        // --- UX MEJORADA: Textos más claros y amigables ---
        promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Inicio de sesión seguro")
            .setSubtitle("Verifica tu identidad para entrar a $appName")
            .setNegativeButtonText("Cancelar")
            .setConfirmationRequired(false) 
            .build()
    }

    private fun authenticateUser() {
        val biometricManager = BiometricManager.from(this)
        if (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS) {
            biometricPrompt.authenticate(promptInfo)
        } else {
            // Si no hay biometría configurada, permitimos pasar
            Log.w(TAG, "⚠️ Biometría no disponible - autocompletando directamente")
            onAuthenticationSuccess()
        }
    }

    private fun onAuthenticationSuccess() {
        try {
            // A. Recuperar los datos planos
            val username = intent.getStringExtra("username") ?: ""
            val password = intent.getStringExtra("password") ?: ""
            val appName = intent.getStringExtra("app_name") ?: "App"

            // B. Recuperar los IDs de los campos (Parcelables reales)
            val usernameIds = intent.getParcelableArrayListExtra<AutofillId>("username_ids")
            val passwordIds = intent.getParcelableArrayListExtra<AutofillId>("password_ids")

            // C. Construir el Dataset de respuesta
            val datasetBuilder = Dataset.Builder()

            // Llenar campos de usuario
            if (username.isNotEmpty() && usernameIds != null) {
                for (id in usernameIds) {
                    datasetBuilder.setValue(id, AutofillValue.forText(username))
                }
            }

            // Llenar campos de contraseña
            if (password.isNotEmpty() && passwordIds != null) {
                for (id in passwordIds) {
                    datasetBuilder.setValue(id, AutofillValue.forText(password))
                }
            }

            // D. Devolver el resultado al sistema Android Autofill
            val replyIntent = Intent()
            replyIntent.putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, datasetBuilder.build())
            
            setResult(Activity.RESULT_OK, replyIntent)
            
            // UX MEJORADA: Feedback de éxito con el ícono del candado
            Toast.makeText(this, "🔓 $appName desbloqueada", Toast.LENGTH_SHORT).show()
            finish()

        } catch (e: Exception) {
            Log.e(TAG, "Error construyendo dataset post-auth", e)
            setResult(RESULT_CANCELED)
            finish()
        }
    }
}