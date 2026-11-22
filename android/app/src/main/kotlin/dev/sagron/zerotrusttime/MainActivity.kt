package dev.sagron.zerotrusttime

import dev.sagron.zerotrusttime.notify.RunningTimerNotification
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * FlutterFragmentActivity, not FlutterActivity: the biometric prompt
 * (local_auth) needs a FragmentActivity.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        RunningTimerNotification.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
