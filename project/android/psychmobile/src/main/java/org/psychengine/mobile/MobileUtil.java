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
	private static Vibrator cachedVibrator = null;

	private static Vibrator getVibrator()
	{
		if (cachedVibrator != null) return cachedVibrator;
		Context context = Extension.mainContext;
		if (context == null) return null;
		try
		{
			Vibrator vibrator = (Vibrator)context.getSystemService(Context.VIBRATOR_SERVICE);
			if (vibrator != null && vibrator.hasVibrator()) cachedVibrator = vibrator;
		}
		catch (Exception e) {}
		return cachedVibrator;
	}

	private static final int[] HAPTIC_DURATIONS = { 12, 22, 40 };
	private static final int[] HAPTIC_AMPLITUDES = { 70, 140, 220 };

	public static void haptic(int strength, int intensityPercent)
	{
		if (intensityPercent <= 0) return;
		Vibrator vibrator = getVibrator();
		if (vibrator == null) return;
		int index = Math.max(0, Math.min(2, strength));
		float intensity = intensityPercent / 100f;
		int duration = Math.round(HAPTIC_DURATIONS[index] * (intensity <= 1 ? 1 : 1 + (intensity - 1) * 0.25f));
		try
		{
			if (Build.VERSION.SDK_INT >= 26)
			{
				int amplitude = VibrationEffect.DEFAULT_AMPLITUDE;
				if (vibrator.hasAmplitudeControl()) amplitude = Math.max(1, Math.min(255, Math.round(HAPTIC_AMPLITUDES[index] * intensity)));
				else duration = Math.max(5, Math.round(HAPTIC_DURATIONS[index] * Math.max(0.4f, intensity)));
				vibrator.vibrate(VibrationEffect.createOneShot(duration, amplitude));
			}
			else vibrator.vibrate(Math.max(5, Math.round(HAPTIC_DURATIONS[index] * Math.max(0.4f, intensity))));
		}
		catch (Exception e) {}
	}

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
