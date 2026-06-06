package com.example.password_manager

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class CryptographyManager {

    private val ANDROID_KEYSTORE = "AndroidKeyStore"
    private val KEY_ALIAS = "MyPasswordManagerKey" // El nombre de tu llave maestra

    private val encryptionCipher: Cipher
        get() = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        }

    private val keyStore: KeyStore
        get() = KeyStore.getInstance(ANDROID_KEYSTORE).apply {
            load(null)
        }

    private fun getDecryptionCipher(iv: ByteArray): Cipher {
        return Cipher.getInstance(TRANSFORMATION).apply {
            val spec = GCMParameterSpec(128, iv)
            init(Cipher.DECRYPT_MODE, getOrCreateKey(), spec)
        }
    }

    private fun getOrCreateKey(): SecretKey {
        val existingKey = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
        return existingKey ?: createKey()
    }

    private fun createKey(): SecretKey {
        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val keyGenParameterSpec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .build()
        
        keyGenerator.init(keyGenParameterSpec)
        return keyGenerator.generateKey()
    }

    fun encryptData(plaintext: String): EncryptedData {
        val cipher = encryptionCipher
        val ciphertext = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        return EncryptedData(ciphertext, cipher.iv)
    }

    fun decryptData(ciphertext: ByteArray, iv: ByteArray): String {
        val cipher = getDecryptionCipher(iv)
        val plaintextBytes = cipher.doFinal(ciphertext)
        return String(plaintextBytes, Charsets.UTF_8)
    }

    companion object {
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
    }
}

data class EncryptedData(val ciphertext: ByteArray, val iv: ByteArray)