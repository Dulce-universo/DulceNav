// ============================================================
// DulceNav — MainActivity.kt
// Actividad principal de Android con MethodChannel para Keystore nativo.
// ============================================================

package com.dulce.nav

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.view.WindowManager

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.dulce.nav/keystore"
    private val KEY_ALIAS = "dulce_master_key"
    private val ANDROID_KEYSTORE = "AndroidKeyStore"
    private val TRANSFORMATION = "AES/GCM/NoPadding"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "encrypt" -> {
                    val plainText = call.argument<String>("data")
                    if (plainText != null) {
                        try {
                            val encrypted = encryptData(plainText)
                            result.success(encrypted)
                        } catch (e: Exception) {
                            result.error("ENCRYPT_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Data must not be null", null)
                    }
                }
                "decrypt" -> {
                    val encryptedText = call.argument<String>("data")
                    if (encryptedText != null) {
                        try {
                            val decrypted = decryptData(encryptedText)
                            result.success(decrypted)
                        } catch (e: Exception) {
                            result.error("DECRYPT_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Data must not be null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.dulce.nav/notification").setMethodCallHandler { call, result ->
            when (call.method) {
                "showProgress" -> {
                    val id = call.argument<String>("id") ?: ""
                    val fileName = call.argument<String>("fileName") ?: "Descarga"
                    val progress = call.argument<Int>("progress") ?: 0
                    val speed = call.argument<String>("speed") ?: ""
                    showProgressNotification(id, fileName, progress, speed)
                    result.success(null)
                }
                "showCompleted" -> {
                    val id = call.argument<String>("id") ?: ""
                    val fileName = call.argument<String>("fileName") ?: "Descarga"
                    showCompletedNotification(id, fileName)
                    result.success(null)
                }
                "showError" -> {
                    val id = call.argument<String>("id") ?: ""
                    val fileName = call.argument<String>("fileName") ?: "Descarga"
                    showErrorNotification(id, fileName)
                    result.success(null)
                }
                "cancelNotification" -> {
                    val id = call.argument<String>("id") ?: ""
                    cancelNotification(id)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.dulce.nav/window_manager").setMethodCallHandler { call, result ->
            when (call.method) {
                "addFlags" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "clearFlags" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val keyEntry = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (keyEntry != null) {
            return keyEntry.secretKey
        }

        // Generar nueva clave si no existe
        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }

    private fun encryptData(plainText: String): String {
        val key = getSecretKey()
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val iv = cipher.iv // IV autogenerado de 12 bytes para GCM
        val cipherText = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))

        // Concatenar IV (12 bytes) + CipherText
        val payload = ByteArray(iv.size + cipherText.size)
        System.arraycopy(iv, 0, payload, 0, iv.size)
        System.arraycopy(cipherText, 0, payload, iv.size, cipherText.size)

        return Base64.encodeToString(payload, Base64.NO_WRAP)
    }

    private fun decryptData(encryptedText: String): String {
        val key = getSecretKey()
        val payload = Base64.decode(encryptedText, Base64.NO_WRAP)

        // Extraer IV (primeros 12 bytes) y CipherText
        val ivSize = 12
        if (payload.size <= ivSize) {
            throw IllegalArgumentException("Invalid encrypted payload size")
        }
        val iv = ByteArray(ivSize)
        val cipherText = ByteArray(payload.size - ivSize)
        System.arraycopy(payload, 0, iv, 0, ivSize)
        System.arraycopy(payload, ivSize, cipherText, 0, cipherText.size)

        val cipher = Cipher.getInstance(TRANSFORMATION)
        val spec = GCMParameterSpec(128, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)
        val plainTextBytes = cipher.doFinal(cipherText)

        return String(plainTextBytes, Charsets.UTF_8)
    }

    private fun showProgressNotification(id: String, fileName: String, progress: Int, speed: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "downloads_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Descargas", NotificationManager.IMPORTANCE_LOW)
            channel.description = "Progreso de descargas de DulceNav"
            notificationManager.createNotificationChannel(channel)
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, channelId)
        } else {
            android.app.Notification.Builder(this)
        }

        builder.setContentTitle(fileName)
            .setContentText("$progress% - $speed")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setProgress(100, progress, progress == -1)
            .setOngoing(true)
            .setAutoCancel(false)

        notificationManager.notify(id.hashCode(), builder.build())
    }

    private fun showCompletedNotification(id: String, fileName: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "downloads_channel"

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, channelId)
        } else {
            android.app.Notification.Builder(this)
        }

        builder.setContentTitle(fileName)
            .setContentText("Descarga completada")
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setProgress(0, 0, false)
            .setOngoing(false)
            .setAutoCancel(true)

        notificationManager.notify(id.hashCode(), builder.build())
    }

    private fun showErrorNotification(id: String, fileName: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "downloads_channel"

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(this, channelId)
        } else {
            android.app.Notification.Builder(this)
        }

        builder.setContentTitle(fileName)
            .setContentText("Error en la descarga")
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setProgress(0, 0, false)
            .setOngoing(false)
            .setAutoCancel(true)

        notificationManager.notify(id.hashCode(), builder.build())
    }

    private fun cancelNotification(id: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(id.hashCode())
    }
}
