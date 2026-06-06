package com.example.password_manager

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import com.google.gson.Gson

class SecureRepository(context: Context) {

    private val PREFS_NAME = "MySecureVault"
    private val DATA_KEY = "encrypted_vault_data"
    private val IV_KEY = "vault_iv"
    
    // Usamos SharedPreferences común para que sea accesible, pero el contenido estará encriptado
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val cryptoManager = CryptographyManager()

    // Guardar (Recibe el JSON limpio desde Flutter, lo encripta y lo guarda)
    fun saveVault(jsonString: String) {
        val encryptedData = cryptoManager.encryptData(jsonString)
        
        // Convertimos a String Base64 para guardar
        val ciphertextString = Base64.encodeToString(encryptedData.ciphertext, Base64.DEFAULT)
        val ivString = Base64.encodeToString(encryptedData.iv, Base64.DEFAULT)

        prefs.edit()
            .putString(DATA_KEY, ciphertextString)
            .putString(IV_KEY, ivString)
            .apply()
    }

    // Leer (Lee el archivo, desencripta con Keystore y devuelve el JSON limpio)
    fun getVault(): String? {
        val ciphertextString = prefs.getString(DATA_KEY, null)
        val ivString = prefs.getString(IV_KEY, null)

        if (ciphertextString == null || ivString == null) return null

        return try {
            val ciphertext = Base64.decode(ciphertextString, Base64.DEFAULT)
            val iv = Base64.decode(ivString, Base64.DEFAULT)
            
            cryptoManager.decryptData(ciphertext, iv)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}