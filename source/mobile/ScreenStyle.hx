package mobile;

import flixel.system.scaleModes.RatioScaleMode;

class ScreenStyle
{
	public static inline final ORIGINAL:String = 'Original';
	public static inline final FULL:String = 'Full';

	static var listening:Bool = false;
	static var lastWidth:Int = 0;

	public static function apply()
	{
		if (FlxG.game == null) return;
		if (!listening)
		{
			listening = true;
			FlxG.signals.gameResized.add(function(_, _) resizeCameras());
		}

		var full:Bool = ClientPrefs.data.screenStyle == FULL;
		if (full && Std.isOfType(FlxG.scaleMode, WideScaleMode)) return;
		if (!full && Std.isOfType(FlxG.scaleMode, RatioScaleMode)) return;

		lastWidth = FlxG.width;
		FlxG.scaleMode = full ? new WideScaleMode() : new RatioScaleMode();
		resizeCameras();
	}

	static function resizeCameras()
	{
		if (lastWidth == 0) lastWidth = FlxG.initialWidth;
		if (lastWidth != FlxG.width)
		{
			for (camera in FlxG.cameras.list)
				if (camera != null && camera.width == lastWidth)
					camera.setSize(FlxG.width, FlxG.height);
		}
		lastWidth = FlxG.width;
	}
}
