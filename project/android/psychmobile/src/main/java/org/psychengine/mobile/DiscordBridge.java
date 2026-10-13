package org.psychengine.mobile;

import android.app.Activity;
import android.content.pm.PackageManager;
import java.lang.reflect.Method;
import org.haxe.extension.Extension;

public class DiscordBridge
{
	private static final String SDK_INIT_CLASS = "com.discord.socialsdk.DiscordSocialSdkInit";
	private static final String[] DISCORD_PACKAGES = { "com.discord", "com.discord.canary", "com.discord.ptb" };

	private static boolean prepared = false;

	public static boolean isDiscordInstalled()
	{
		Activity activity = Extension.mainActivity;
		if (activity == null) return false;
		PackageManager manager = activity.getPackageManager();
		for (String name : DISCORD_PACKAGES)
		{
			try
			{
				manager.getPackageInfo(name, 0);
				return true;
			}
			catch (PackageManager.NameNotFoundException e) {}
		}
		return false;
	}

	public static boolean prepare()
	{
		if (prepared) return true;

		final Activity activity = Extension.mainActivity;
		if (activity == null || !isDiscordInstalled()) return false;

		try
		{
			System.loadLibrary("discord_partner_sdk");
			Class<?> init = Class.forName(SDK_INIT_CLASS);
			final Method setEngineActivity = init.getMethod("setEngineActivity", Activity.class);
			setEngineActivity.invoke(null, activity);
			prepared = true;
		}
		catch (Throwable e)
		{
			prepared = false;
		}
		return prepared;
	}
}
