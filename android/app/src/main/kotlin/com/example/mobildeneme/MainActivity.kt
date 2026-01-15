package com.example.mobildeneme

import android.content.Context
import android.content.res.Configuration
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.util.Locale

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    }
    
    override fun attachBaseContext(newBase: Context?) {
        super.attachBaseContext(newBase?.let { context ->
            val config = Configuration(context.resources.configuration)
            config.setLocale(Locale("tr", "TR"))
            context.createConfigurationContext(config)
        })
    }
}
