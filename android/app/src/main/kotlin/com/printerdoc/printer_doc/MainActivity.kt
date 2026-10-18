// Android entry point. Also exposes one small platform channel so the Edge
// Status self-check can read the permissions this APK really declares,
// instead of assuming INTERNET is absent.
package com.printerdoc.printer_doc

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "printer_doc/edge")
            .setMethodCallHandler { call, result ->
                if (call.method == "declaredPermissions") {
                    // Reads the merged manifest of the installed APK, so it
                    // includes permissions added by plugins as well.
                    @Suppress("DEPRECATION")
                    val info = packageManager.getPackageInfo(
                        packageName, PackageManager.GET_PERMISSIONS
                    )
                    result.success(info.requestedPermissions?.toList() ?: emptyList<String>())
                } else {
                    result.notImplemented()
                }
            }
    }
}
