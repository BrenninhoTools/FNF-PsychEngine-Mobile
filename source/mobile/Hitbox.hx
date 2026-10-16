package mobile;

import flixel.util.FlxGradient;
import openfl.display.BitmapData;
import openfl.geom.Point;
import openfl.geom.Rectangle;

class Hitbox extends FlxSpriteGroup
{
	public static final STYLES:Array<String> = ['Gradient', 'Solid', 'Outline', 'Bottom Glow', 'Edges'];
	public static final COLOR_MODES:Array<String> = ['Notes', 'Classic', 'Pastel', 'White'];

	static final CLASSIC:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
	static final PASTEL:Array<FlxColor> = [0xFFE7A6F2, 0xFFA6E9F2, 0xFFB8F2A6, 0xFFF2A6AC];
	static inline final FADE_OUT_SPEED:Float = 8;

	public var preview:Bool;

	var lanes:Array<FlxSprite> = [];

	public function new(preview:Bool = false)
	{
		super();
		this.preview = preview;

		var laneWidth:Int = Std.int(Math.ceil(FlxG.width / TouchInput.LANES));
		for (i in 0...TouchInput.LANES)
		{
			var lane:FlxSprite = new FlxSprite(i * laneWidth, 0);
			lane.alpha = 0;
			lane.antialiasing = ClientPrefs.data.antialiasing;
			lanes.push(lane);
			add(lane);
		}
		refresh();

		scrollFactor.set();
		TouchInput.hitboxEnabled = true;
	}

	public function refresh()
	{
		var laneWidth:Int = Std.int(Math.ceil(FlxG.width / TouchInput.LANES));
		var bitmap:BitmapData = createLaneBitmap(ClientPrefs.data.hitboxStyle, laneWidth, FlxG.height);
		for (i in 0...lanes.length)
		{
			lanes[i].loadGraphic(bitmap.clone());
			lanes[i].color = laneColor(i);
		}
		bitmap.dispose();
		visible = preview || !ClientPrefs.data.hitboxInvisible;
	}

	public static function laneColor(lane:Int):FlxColor
	{
		return switch (ClientPrefs.data.hitboxColors)
		{
			case 'Notes':
				var colors:Array<FlxColor> = ClientPrefs.data.arrowRGB[lane % ClientPrefs.data.arrowRGB.length];
				colors != null && colors.length > 0 ? colors[0] : CLASSIC[lane % CLASSIC.length];
			case 'Pastel': PASTEL[lane % PASTEL.length];
			case 'White': FlxColor.WHITE;
			default: CLASSIC[lane % CLASSIC.length];
		}
	}

	static function createLaneBitmap(style:String, width:Int, height:Int):BitmapData
	{
		var bitmap:BitmapData;
		switch (style)
		{
			case 'Solid':
				bitmap = new BitmapData(width, height, true, 0x70FFFFFF);
				bitmap.fillRect(new Rectangle(0, 0, 3, height), 0xFFFFFFFF);
				bitmap.fillRect(new Rectangle(width - 3, 0, 3, height), 0xFFFFFFFF);

			case 'Outline':
				bitmap = new BitmapData(width, height, true, 0x18FFFFFF);
				var thickness:Int = 8;
				var inset:Int = 4;
				bitmap.fillRect(new Rectangle(inset, inset, width - inset * 2, thickness), 0xFFFFFFFF);
				bitmap.fillRect(new Rectangle(inset, height - inset - thickness, width - inset * 2, thickness), 0xFFFFFFFF);
				bitmap.fillRect(new Rectangle(inset, inset, thickness, height - inset * 2), 0xFFFFFFFF);
				bitmap.fillRect(new Rectangle(width - inset - thickness, inset, thickness, height - inset * 2), 0xFFFFFFFF);

			case 'Bottom Glow':
				bitmap = FlxGradient.createGradientBitmapData(width, height, [0x00FFFFFF, 0x10FFFFFF, 0xD0FFFFFF], 1, 90);

			case 'Edges':
				bitmap = FlxGradient.createGradientBitmapData(width, height, [0xE0FFFFFF, 0x00FFFFFF, 0x00FFFFFF, 0xE0FFFFFF], 1, 0);

			default:
				bitmap = FlxGradient.createGradientBitmapData(width, height, [0xB0FFFFFF, 0x10FFFFFF, 0x10FFFFFF, 0xB0FFFFFF], 1, 0);
				var glow:BitmapData = FlxGradient.createGradientBitmapData(width, Std.int(height * 0.35), [0x00FFFFFF, 0x60FFFFFF], 1, 90);
				bitmap.copyPixels(glow, glow.rect, new Point(0, height - glow.height), null, null, true);
				glow.dispose();
				bitmap.fillRect(new Rectangle(0, 0, 4, height), 0xFFFFFFFF);
				bitmap.fillRect(new Rectangle(width - 4, 0, 4, height), 0xFFFFFFFF);
		}
		return bitmap;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var opacity:Float = ClientPrefs.data.hitboxOpacity;
		var idle:Float = preview ? opacity * 0.3 : 0;
		for (i in 0...lanes.length)
		{
			if (TouchInput.lanePressedAt(i))
				lanes[i].alpha = opacity;
			else if (lanes[i].alpha > idle)
			{
				lanes[i].alpha -= (lanes[i].alpha - idle) * Math.min(1, elapsed * FADE_OUT_SPEED);
				if (lanes[i].alpha - idle < 0.01) lanes[i].alpha = idle;
			}
			else lanes[i].alpha = idle;
		}
	}

	override function destroy()
	{
		TouchInput.hitboxEnabled = false;
		if (Controls.instance != null) Controls.instance.controllerMode = false;
		super.destroy();
	}
}
