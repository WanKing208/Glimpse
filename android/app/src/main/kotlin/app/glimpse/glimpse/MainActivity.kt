package app.glimpse.glimpse

import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "glimpse/display"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "refreshRate" -> result.success(currentRefreshRate())
                    "maxRefreshRate" -> result.success(maxRefreshRate())
                    "forceMax" -> {
                        requestMaxRefreshRate()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestMaxRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        requestMaxRefreshRate()
    }

    @Suppress("DEPRECATION")
    private fun display(): Display? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            windowManager.defaultDisplay
        }

    private fun currentRefreshRate(): Float {
        return try {
            display()?.refreshRate ?: 0f
        } catch (_: Throwable) {
            0f
        }
    }

    private fun maxRefreshRate(): Float {
        return try {
            display()?.supportedModes?.maxOfOrNull { it.refreshRate } ?: 0f
        } catch (_: Throwable) {
            0f
        }
    }

    /**
     * 尽量把屏幕刷新率顶到该分辨率下的最高档。
     * ColorOS 的高刷白名单不收录侧载应用，这里直接用
     * preferredDisplayModeId + preferredRefreshRate + 反射 setFrameRate 三条路一起试。
     */
    private fun requestMaxRefreshRate() {
        try {
            val d = display() ?: return
            val best = d.supportedModes?.maxByOrNull { it.refreshRate } ?: return
            val attrs = window.attributes
            attrs.preferredRefreshRate = best.refreshRate
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                attrs.preferredDisplayModeId = best.modeId
            }
            window.attributes = attrs

            // Window.setFrameRate(float, int) 是 API 30 的隐藏性较强的接口，用反射避免编译期依赖
            try {
                val m = window.javaClass.getMethod(
                    "setFrameRate",
                    Float::class.javaPrimitiveType,
                    Int::class.javaPrimitiveType,
                )
                m.invoke(window, best.refreshRate, 1) // 1 = FIXED_SOURCE
            } catch (_: Throwable) {
            }
        } catch (_: Throwable) {
        }
    }
}
