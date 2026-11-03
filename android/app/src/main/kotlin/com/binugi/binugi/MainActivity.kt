package com.binugi.binugi

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // 런처 아이콘 바꾸기: activity-alias 중 하나만 켭니다. (앱 식별자는 바뀌지 않음)
    private val aliases = listOf("box", "house", "recycle", "sparkle")

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
    }

    private fun component(name: String) =
        ComponentName(packageName, "com.binugi.binugi.Launcher" + name.replaceFirstChar { it.uppercase() })
}
