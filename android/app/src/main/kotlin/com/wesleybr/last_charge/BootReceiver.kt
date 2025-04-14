package com.wesleybr.last_charge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // Iniciar o serviço quando o dispositivo for reiniciado
            BatteryMonitorService.startService(context)
        }
    }
}
