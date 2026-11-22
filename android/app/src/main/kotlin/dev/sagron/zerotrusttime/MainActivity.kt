package dev.sagron.zerotrusttime

import android.content.Intent
import android.os.Bundle
import dev.sagron.zerotrusttime.links.ZtLinks
import dev.sagron.zerotrusttime.notify.RunningTimerNotification
import dev.sagron.zerotrusttime.places.PlaceTimer
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * FlutterFragmentActivity, not FlutterActivity: the biometric prompt
 * (local_auth) needs a FragmentActivity.
 */
class MainActivity : FlutterFragmentActivity() {
    private val links = ZtLinks(this)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Only here does Android say which app asked (see ZtLinks).
        links.onCreate(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        RunningTimerNotification.register(this, messenger)
        links.register(messenger)
        PlaceTimer.register(this, messenger)
    }

    override fun onNewIntent(intent: Intent) {
        // A track request is only honoured on its own screen (onCreate),
        // where Android says who is asking.
        if (ZtLinks.isTrack(intent)) return
        super.onNewIntent(intent)
    }

    @Deprecated("Deprecated in Android, still the simplest hook here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (links.onActivityResult(requestCode, resultCode, data)) return
        super.onActivityResult(requestCode, resultCode, data)
    }
}
