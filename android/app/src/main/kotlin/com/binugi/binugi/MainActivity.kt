package com.binugi.binugi

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // 런처 아이콘 바꾸기: activity-alias 중 하나만 켭니다. (앱 식별자는 바뀌지 않음)
    private val aliases = listOf("box", "house", "recycle", "sparkle")

    // 백업 파일을 앱 밖(다운로드 폴더·드라이브 등)에 저장: 시스템 "저장 위치" 화면 (권한 필요 없음)
    private val saveRequest = 4401
    private var pendingSave: MethodChannel.Result? = null
    private var pendingSavePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "binugi/launcher").setMethodCallHandler { call, result ->
            when (call.method) {
                "setIcon" -> {
                    val name = call.argument<String>("name") ?: "box"
                    if (!aliases.contains(name)) {
                        result.error("bad", "unknown icon", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val pm = packageManager
                        // 새 것을 먼저 켜고 나머지를 끔 (아이콘이 잠깐이라도 사라지지 않게)
                        pm.setComponentEnabledSetting(component(name), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                        for (a in aliases) {
                            if (a != name) {
                                pm.setComponentEnabledSetting(component(a), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("fail", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "binugi/files").setMethodCallHandler { call, result ->
            when (call.method) {
                "saveCopy" -> {
                    val path = call.argument<String>("path")
                    if (path == null || !File(path).isFile) {
                        result.error("bad", "no file", null)
                        return@setMethodCallHandler
                    }
                    if (pendingSave != null) {
                        result.error("busy", "already saving", null)
                        return@setMethodCallHandler
                    }
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = call.argument<String>("mime") ?: "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: File(path).name)
                    }
                    pendingSave = result
                    pendingSavePath = path
                    try {
                        startActivityForResult(intent, saveRequest)
                    } catch (e: Exception) {
                        pendingSave = null
                        pendingSavePath = null
                        result.error("fail", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequest) return
        val res = pendingSave ?: return
        val path = pendingSavePath
        pendingSave = null
        pendingSavePath = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || path == null) {
            res.success(null) // 사용자가 취소
            return
        }
        Thread {
            try {
                val src = File(path)
                val written = contentResolver.openOutputStream(uri)?.use { out -> src.inputStream().use { it.copyTo(out) } }
                    ?: throw IllegalStateException("cannot open target")
                if (written != src.length()) throw IllegalStateException("size mismatch")
                val name = displayName(uri)
                runOnUiThread { res.success(name) }
            } catch (e: Exception) {
                runOnUiThread { res.error("fail", e.message, null) }
            }
        }.start()
    }

    private fun displayName(uri: Uri): String {
        val n = try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) c.getString(0) else null
            }
        } catch (e: Exception) {
            null
        }
        return n ?: uri.lastPathSegment ?: "백업 파일"
    }

    private fun component(name: String) =
        ComponentName(packageName, "com.binugi.binugi.Launcher" + name.replaceFirstChar { it.uppercase() })
}
