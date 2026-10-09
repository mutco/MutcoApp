package com.usk.mutco

import android.app.UiModeManager
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingExport: Pair<ByteArray, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.usk.mutco/theme")
            .setMethodCallHandler { call, result ->
                if (call.method != "setDark") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val dark = call.arguments as? Boolean
                if (dark == null) {
                    result.error("ARGUMENT", "Expected a boolean theme value", null)
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val manager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    val mode = if (dark) UiModeManager.MODE_NIGHT_YES else UiModeManager.MODE_NIGHT_NO
                    val preferences = getSharedPreferences("mutco_native_theme", Context.MODE_PRIVATE)
                    if (!preferences.contains("dark") || preferences.getBoolean("dark", false) != dark) {
                        manager.setApplicationNightMode(mode)
                        preferences.edit().putBoolean("dark", dark).apply()
                    }
                }
                result.success(null)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.usk.mutco/export")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePng") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val arguments = call.arguments as? Map<*, *>
                val bytes = arguments?.get("bytes") as? ByteArray
                val requestedName = arguments?.get("name") as? String
                if (bytes == null || bytes.isEmpty() || requestedName.isNullOrBlank()) {
                    result.error("ARGUMENT", "Expected PNG bytes and file name", null)
                    return@setMethodCallHandler
                }
                val name = requestedName.replace(Regex("[^A-Za-z0-9._-]"), "_")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    saveToPictures(name, bytes, result)
                } else {
                    if (pendingExport != null) {
                        result.error("BUSY", "Another image is being saved", null)
                        return@setMethodCallHandler
                    }
                    pendingExport = Pair(bytes, result)
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "image/png"
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    try {
                        startActivityForResult(intent, 8401)
                    } catch (error: Exception) {
                        pendingExport = null
                        result.error("EXPORT", error.message, null)
                    }
                }
            }
    }

    private fun saveToPictures(name: String, bytes: ByteArray, result: MethodChannel.Result) {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Mutco")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        var uri: android.net.Uri? = null
        try {
            uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Could not create image")
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IllegalStateException("Could not write image")
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            result.success(uri.toString())
        } catch (error: Exception) {
            if (uri != null) contentResolver.delete(uri, null, null)
            result.error("EXPORT", error.message, null)
        }
    }

    @Deprecated("Android document picker callback for devices below Android 10")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 8401) return
        val export = pendingExport ?: return
        pendingExport = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            export.second.error("CANCELLED", "Image export cancelled", null)
            return
        }
        try {
            contentResolver.openOutputStream(uri)?.use { it.write(export.first) }
                ?: throw IllegalStateException("Could not write image")
            export.second.success(uri.toString())
        } catch (error: Exception) {
            export.second.error("EXPORT", error.message, null)
        }
    }
}
