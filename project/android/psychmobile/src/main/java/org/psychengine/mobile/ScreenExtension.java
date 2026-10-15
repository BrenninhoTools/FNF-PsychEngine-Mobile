package org.psychengine.mobile;

import android.app.Activity;
import android.os.Build;
import android.os.Bundle;
import android.view.Window;
import android.view.WindowManager;
import org.haxe.extension.Extension;

public class ScreenExtension extends Extension
{
	@Override
	public void onCreate(Bundle savedInstanceState)
	{
		useCutoutArea();
	}

	@Override
	public void onResume()
	{
		useCutoutArea();
	}

	private static void useCutoutArea()
	{
		if (Build.VERSION.SDK_INT < 28) return;
		Activity activity = Extension.mainActivity;
		if (activity == null) return;
		Window window = activity.getWindow();
		if (window == null) return;

		WindowManager.LayoutParams params = window.getAttributes();
		int mode = Build.VERSION.SDK_INT >= 30 ? WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS : WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
		if (params.layoutInDisplayCutoutMode != mode)
		{
			params.layoutInDisplayCutoutMode = mode;
			window.setAttributes(params);
		}
	}
}
