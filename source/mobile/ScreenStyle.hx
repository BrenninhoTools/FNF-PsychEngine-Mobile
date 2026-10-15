package mobile;

import flixel.system.scaleModes.FillScaleMode;
import flixel.system.scaleModes.RatioScaleMode;

class ScreenStyle
{
	public static inline final ORIGINAL:String = 'Original';
	public static inline final FULL:String = 'Full';

	public static function apply()
	{
		if (FlxG.game == null) return;
		var full:Bool = ClientPrefs.data.screenStyle == FULL;
		if (full && Std.isOfType(FlxG.scaleMode, FillScaleMode)) return;
		if (!full && Std.isOfType(FlxG.scaleMode, RatioScaleMode)) return;
		FlxG.scaleMode = full ? new FillScaleMode() : new RatioScaleMode();
	}
}
