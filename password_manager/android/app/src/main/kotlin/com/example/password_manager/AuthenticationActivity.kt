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
import android.widget.RemoteViews
import android.widget.Toast
import androidx.annotation.RequiresApi
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity

@RequiresApi(Build.VERSION_CODES.O)
class AuthenticationActivity : FragmentActivity() {

    companion object {
        private const val TAG = "AuthActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "Iniciada para: ${intent.getStringExtra("app_name")}")
        authenticateUser()
    }

    private fun authenticateUser() {
        val biometricManager = BiometricManager.from(this)
        val canAuthenticate = biometricManager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
            BiometricManager.Authenticators.BIOMETRIC_WEAK
        )
        Log.d(TAG, "Estado biométrico: $canAuthenticate")

        if (canAuthenticate != BiometricManager.BIOMETRIC_SUCCESS) {
            Log.w(TAG, "Sin biometría disponible, rellenando directo.")
            onAuthenticationSuccess()
            return
        }

        val executor = ContextCompat.getMainExecutor(this)

        val callback = object : BiometricPrompt.AuthenticationCallback() {
            override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                super.onAuthenticationError(errorCode, errString)
                Log.e(TAG, "Error biométrico ($errorCode): $errString")
                setResult(RESULT_CANCELED)
                finish()
            }

            override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                super.onAuthenticationSucceeded(result)
                Log.d(TAG, "Huella verificada OK.")
                onAuthenticationSuccess()
            }

            override fun onAuthenticationFailed() {
                super.onAuthenticationFailed()
                Toast.makeText(applicationContext, "Huella no reconocida", Toast.LENGTH_SHORT).show()
            }
        }

        // FIX: Un solo PromptInfo SIN setNegativeButtonText().
        // Cuando se incluye DEVICE_CREDENTIAL en setAllowedAuthenticators(),
        // agregar setNegativeButtonText() lanza IllegalArgumentException y crashea.
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Inicio de sesión seguro")
            .setSubtitle("Verifica tu identidad para entrar a ${intent.getStringExtra("app_name") ?: "la app"}")
            .setConfirmationRequired(false)
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.BIOMETRIC_WEAK or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()

        BiometricPrompt(this, executor, callback).authenticate(promptInfo)
    }

    private fun onAuthenticationSuccess() {
        try {
            val username = intent.getStringExtra("username") ?: ""
            val password = intent.getStringExtra("password") ?: ""
            val appName  = intent.getStringExtra("app_name") ?: "App"

            Log.d(TAG, "Construyendo Dataset → app=$appName, pass=${if (password.isNotEmpty()) "OK" else "VACÍO"}")

            val usernameIds: ArrayList<AutofillId>? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra("username_ids", AutofillId::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra("username_ids")
                }

            val passwordIds: ArrayList<AutofillId>? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra("password_ids", AutofillId::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra("password_ids")
                }

            Log.d(TAG, "IDs → usernameIds=${usernameIds?.size}, passwordIds=${passwordIds?.size}")

            val responsePresentation = RemoteViews(packageName, R.layout.autofill_item).apply {
                setTextViewText(R.id.autofill_title, "🔐 $appName")
                setTextViewText(R.id.autofill_subtitle, username.ifEmpty { "Autocompletado" })
            }

            val datasetBuilder = Dataset.Builder(responsePresentation)
            var hasValues = false

            if (username.isNotEmpty() && !usernameIds.isNullOrEmpty()) {
                for (id in usernameIds) {
                    datasetBuilder.setValue(id, AutofillValue.forText(username))
                    hasValues = true
                }
            }

            if (password.isNotEmpty() && !passwordIds.isNullOrEmpty()) {
                for (id in passwordIds) {
                    datasetBuilder.setValue(id, AutofillValue.forText(password))
                    hasValues = true
                }
            }

            if (!hasValues) {
                Log.e(TAG, "Sin valores para rellenar.")
                setResult(RESULT_CANCELED)
                finish()
                return
            }

            val replyIntent = Intent().apply {
                putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, datasetBuilder.build())
            }

            Log.d(TAG, "Enviando RESULT_OK.")
            setResult(Activity.RESULT_OK, replyIntent)
            finish()

        } catch (e: Exception) {
            Log.e(TAG, "Excepción construyendo Dataset", e)
            setResult(RESULT_CANCELED)
            finish()
        }
    }
}