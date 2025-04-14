package com.wesleybr.last_charge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.wesleybr.last_charge/battery_service"
    private val BATTERY_STATUS_CHANNEL = "com.wesleybr.last_charge/battery_status"
    private val BATTERY_LEVEL_CHANNEL = "com.wesleybr.last_charge/battery_level"

    private var statusReceiver: BroadcastReceiver? = null
    private var levelReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal para controlar o serviço
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBatteryMonitorService" -> {
                    BatteryMonitorService.startService(this)
                    result.success(true)
                }
                "stopBatteryMonitorService" -> {
                    BatteryMonitorService.stopService(this)
                    result.success(true)
                }
                "requestBatteryOptimizationPermission" -> {
                    requestBatteryOptimizationPermission()
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Canal de eventos para status da bateria
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_STATUS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    statusReceiver = createBatteryStatusReceiver(events)
                    registerReceiver(
                        statusReceiver,
                        IntentFilter("com.wesleybr.last_charge.BATTERY_STATUS_CHANGED")
                    )
                }

                override fun onCancel(arguments: Any?) {
                    statusReceiver?.let { receiver ->
                        try {
                            unregisterReceiver(receiver)
                            statusReceiver = null
                        } catch (e: Exception) {
                            // Ignorar se o receiver não estiver registrado
                        }
                    }
                }
            }
        )

        // Canal de eventos para nível da bateria
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_LEVEL_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    levelReceiver = createBatteryLevelReceiver(events)
                    registerReceiver(
                        levelReceiver,
                        IntentFilter("com.wesleybr.last_charge.BATTERY_LEVEL_CHANGED")
                    )
                }

                override fun onCancel(arguments: Any?) {
                    levelReceiver?.let { receiver ->
                        try {
                            unregisterReceiver(receiver)
                            levelReceiver = null
                        } catch (e: Exception) {
                            // Ignorar se o receiver não estiver registrado
                        }
                    }
                }
            }
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Iniciar o serviço quando o app for aberto
        BatteryMonitorService.startService(this)
    }

    override fun onDestroy() {
        // Desregistrar receivers
        statusReceiver?.let { receiver ->
            try {
                unregisterReceiver(receiver)
                statusReceiver = null
            } catch (e: Exception) {
                // Ignorar se o receiver não estiver registrado
            }
        }

        levelReceiver?.let { receiver ->
            try {
                unregisterReceiver(receiver)
                levelReceiver = null
            } catch (e: Exception) {
                // Ignorar se o receiver não estiver registrado
            }
        }

        super.onDestroy()
    }

    private fun requestBatteryOptimizationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent()
            val packageName = packageName
            val pm = getSystemService(POWER_SERVICE) as PowerManager

            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    private fun createBatteryStatusReceiver(events: EventChannel.EventSink?): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "com.wesleybr.last_charge.BATTERY_STATUS_CHANGED") {
                    val isCharging = intent.getBooleanExtra("isCharging", false)
                    val batteryLevel = intent.getIntExtra("batteryLevel", 0)

                    val data = HashMap<String, Any>()
                    data["isCharging"] = isCharging
                    data["batteryLevel"] = batteryLevel

                    events?.success(data)
                }
            }
        }
    }

    private fun createBatteryLevelReceiver(events: EventChannel.EventSink?): BroadcastReceiver {
        return object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "com.wesleybr.last_charge.BATTERY_LEVEL_CHANGED") {
                    val batteryLevel = intent.getIntExtra("batteryLevel", 0)
                    events?.success(batteryLevel)
                }
            }
        }
    }
}
