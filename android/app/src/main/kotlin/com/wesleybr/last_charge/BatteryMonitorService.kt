package com.wesleybr.last_charge

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.util.concurrent.atomic.AtomicBoolean

class BatteryMonitorService : Service() {
    private val NOTIFICATION_ID = 1
    private val CHANNEL_ID = "battery_monitor_channel"
    private val WAKELOCK_TAG = "LastCharge:BatteryMonitorService"

    private var wakeLock: PowerManager.WakeLock? = null
    private var isServiceRunning = AtomicBoolean(false)
    private var lastBatteryStatus = false
    private var lastBatteryLevel = 0

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_BATTERY_CHANGED) {
                val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                val batteryPct = level * 100 / scale.toFloat()

                val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                                status == BatteryManager.BATTERY_STATUS_FULL

                // Verificar se houve mudança no estado de carregamento
                if (isCharging != lastBatteryStatus) {
                    // Enviar broadcast para o Flutter
                    val batteryIntent = Intent("com.wesleybr.last_charge.BATTERY_STATUS_CHANGED")
                    batteryIntent.putExtra("isCharging", isCharging)
                    batteryIntent.putExtra("batteryLevel", batteryPct.toInt())
                    context.sendBroadcast(batteryIntent)

                    lastBatteryStatus = isCharging
                }

                // Verificar se houve mudança significativa no nível da bateria
                if (Math.abs(batteryPct.toInt() - lastBatteryLevel) >= 5) {
                    lastBatteryLevel = batteryPct.toInt()

                    // Enviar broadcast para o Flutter
                    val levelIntent = Intent("com.wesleybr.last_charge.BATTERY_LEVEL_CHANGED")
                    levelIntent.putExtra("batteryLevel", batteryPct.toInt())
                    context.sendBroadcast(levelIntent)
                }

                // Atualizar notificação
                updateNotification(isCharging, batteryPct.toInt())
            }
        }
    }

    override fun onCreate() {
        super.onCreate()

        // Criar canal de notificação (necessário para Android 8.0+)
        createNotificationChannel()

        // Iniciar como serviço em primeiro plano
        startForeground(NOTIFICATION_ID, createNotification(false, 0))

        // Registrar receiver para monitorar mudanças na bateria
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        registerReceiver(batteryReceiver, filter)

        // Adquirir wakelock parcial para manter o serviço rodando
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKELOCK_TAG
        )
        wakeLock?.acquire(10*60*1000L /*10 minutos*/)

        isServiceRunning.set(true)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Se o serviço for morto pelo sistema, reiniciá-lo
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        // Liberar recursos
        try {
            unregisterReceiver(batteryReceiver)
        } catch (e: Exception) {
            // Ignorar se o receiver não estiver registrado
        }

        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }

        isServiceRunning.set(false)
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Battery Monitor"
            val descriptionText = "Monitors battery charging status"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(isCharging: Boolean, batteryLevel: Int): android.app.Notification {
        val pendingIntent: PendingIntent = Intent(this, MainActivity::class.java).let { notificationIntent ->
            PendingIntent.getActivity(
                this, 0, notificationIntent,
                PendingIntent.FLAG_IMMUTABLE
            )
        }

        val statusText = if (isCharging) "Carregando: $batteryLevel%" else "Nível: $batteryLevel%"

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Last Charge")
            .setContentText(statusText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun updateNotification(isCharging: Boolean, batteryLevel: Int) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, createNotification(isCharging, batteryLevel))
    }

    companion object {
        fun startService(context: Context) {
            val intent = Intent(context, BatteryMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, BatteryMonitorService::class.java)
            context.stopService(intent)
        }
    }
}
