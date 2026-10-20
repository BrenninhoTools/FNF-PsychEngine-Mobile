package org.psychengine.mobile;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.BatteryManager;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.view.WindowManager;
import android.widget.Toast;
import org.haxe.extension.Extension;

public class MobileUtil
{
	public static void toast(final String text, final boolean longDuration)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;
		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				Toast.makeText(activity, text, longDuration ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT).show();
			}
		});
	}

	public static void keepScreenOn(final boolean value)
	{
		final Activity activity = Extension.mainActivity;
		if (activity == null) return;
		activity.runOnUiThread(new Runnable()
		{
			@Override
			public void run()
			{
				if (value) activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
				else activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
			}
		});
	}

	public static int getBatteryLevel()
	{
		Context context = Extension.mainContext;
		if (context == null) return -1;
		try
		{
			Intent battery = context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
			if (battery == null) return -1;
			int level = battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
			int scale = battery.getIntExtra(BatteryManager.EXTRA_SCALE, -1);
			if (level < 0 || scale <= 0) return -1;
			return Math.round(level * 100f / scale);
		}
		catch (Exception e)
		{
			return -1;
		}
	}

	public static boolean isCharging()
	{
		Context context = Extension.mainContext;
		if (context == null) return false;
		try
		{
			Intent battery = context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
			if (battery == null) return false;
			int status = battery.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
			return status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL;
		}
		catch (Exception e)
		{
			return false;
		}
	}

	@SuppressWarnings("deprecation")
	public static void vibrate(int duration)
	{
		Context context = Extension.mainContext;
		if (context == null || duration <= 0) return;
		try
		{
			Vibrator vibrator = (Vibrator)context.getSystemService(Context.VIBRATOR_SERVICE);
			if (vibrator == null || !vibrator.hasVibrator()) return;
			if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE));
			else vibrator.vibrate(duration);
		}
		catch (Exception e) {}
	}
}
