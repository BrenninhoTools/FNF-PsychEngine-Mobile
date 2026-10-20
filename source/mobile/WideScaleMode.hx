package mobile;

import flixel.system.scaleModes.BaseScaleMode;

class WideScaleMode extends BaseScaleMode
{
	override public function onMeasure(Width:Int, Height:Int):Void
	{
		var baseWidth:Int = FlxG.initialWidth;
		var baseHeight:Int = FlxG.initialHeight;
		var width:Int = baseWidth;
		if (Width > 0 && Height > 0 && Width / Height > baseWidth / baseHeight)
			width = Std.int(Math.ceil(baseHeight * Width / Height / 2) * 2);

		@:privateAccess
		{
			FlxG.width = width;
			FlxG.height = baseHeight;
		}

		updateGameSize(Width, Height);
		updateDeviceSize(Width, Height);
		updateScaleOffset();
		updateGamePosition();
	}

	override function updateGameSize(Width:Int, Height:Int):Void
	{
		var ratio:Float = FlxG.width / FlxG.height;
		if (FlxG.width > FlxG.initialWidth)
			gameSize.set(Width, Height);
		else if (Width / Height > ratio)
			gameSize.set(Math.ceil(Height * ratio), Height);
		else
			gameSize.set(Width, Math.ceil(Width / ratio));
	}
}
