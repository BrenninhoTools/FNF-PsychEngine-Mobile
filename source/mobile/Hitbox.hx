package mobile;

import flixel.util.FlxGradient;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.geom.Point;
import openfl.geom.Rectangle;

class Hitbox extends FlxSpriteGroup
{
	public static final STYLES:Array<String> = ['Gradient', 'Solid', 'Outline', 'Bottom Glow', 'Edges', 'Rounded', 'Neon', 'Arrows', 'Corners'];
	public static final COLOR_MODES:Array<String> = ['Notes', 'Classic', 'Pastel', 'White', 'RGB'];

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
		for (i in 0...lanes.length)
		{
			var bitmap:BitmapData = createLaneBitmap(ClientPrefs.data.hitboxStyle, laneWidth, FlxG.height, i);
			lanes[i].loadGraphic(bitmap, false, 0, 0, true);
			lanes[i].color = laneColor(i);
		}
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
			case 'RGB':
				var colors:Array<FlxColor> = ClientPrefs.data.hitboxRGB;
				colors != null && lane < colors.length ? colors[lane] : CLASSIC[lane % CLASSIC.length];
			case 'White': FlxColor.WHITE;
			default: CLASSIC[lane % CLASSIC.length];
		}
	}

	static function createLaneBitmap(style:String, width:Int, height:Int, lane:Int):BitmapData
	{
		var bitmap:BitmapData;
		switch (style)
		{
			case 'Rounded':
				var shape:Shape = new Shape();
				shape.graphics.lineStyle(5, 0xFFFFFF, 1);
				shape.graphics.beginFill(0xFFFFFF, 0.3);
				shape.graphics.drawRoundRect(8, 8, width - 16, height - 16, 48, 48);
				shape.graphics.endFill();
				bitmap = drawShape(shape, width, height);

			case 'Neon':
				bitmap = new BitmapData(width, height, true, 0x08FFFFFF);
				var glow:Int = Std.int(width * 0.22);
				for (x in 0...glow)
				{
					var t:Float = 1 - x / glow;
					var alpha:Int = Std.int(255 * t * t * t);
					var color:Int = (alpha << 24) | 0xFFFFFF;
					bitmap.fillRect(new Rectangle(x, 0, 1, height), color);
					bitmap.fillRect(new Rectangle(width - 1 - x, 0, 1, height), color);
				}

			case 'Arrows':
				var shape:Shape = new Shape();
				shape.graphics.beginFill(0xFFFFFF, 0.18);
				shape.graphics.drawRect(0, 0, width, height);
				shape.graphics.endFill();
				var size:Float = Math.min(width, height) * 0.55;
				var angle:Float = [180, 90, -90, 0][lane % 4] * Math.PI / 180;
				var points:Array<Array<Float>> = [[0.5, 0], [0, -0.48], [0, -0.2], [-0.45, -0.2], [-0.45, 0.2], [0, 0.2], [0, 0.48]];
				shape.graphics.lineStyle(6, 0xFFFFFF, 1);
				shape.graphics.beginFill(0xFFFFFF, 0.55);
				for (i in 0...points.length)
				{
					var px:Float = width / 2 + (points[i][0] * Math.cos(angle) - points[i][1] * Math.sin(angle)) * size;
					var py:Float = height / 2 + (points[i][0] * Math.sin(angle) + points[i][1] * Math.cos(angle)) * size;
					if (i == 0) shape.graphics.moveTo(px, py);
					else shape.graphics.lineTo(px, py);
				}
				shape.graphics.endFill();
				bitmap = drawShape(shape, width, height);

			case 'Corners':
				bitmap = new BitmapData(width, height, true, 0x10FFFFFF);
				var length:Int = Std.int(Math.min(width, height) * 0.25);
				var thick:Int = 10;
				var inset:Int = 6;
				for (corner in [[inset, inset, 1, 1], [width - inset, inset, -1, 1], [inset, height - inset, 1, -1], [width - inset, height - inset, -1, -1]])
				{
					var cx:Int = corner[0];
					var cy:Int = corner[1];
					bitmap.fillRect(new Rectangle(corner[2] > 0 ? cx : cx - length, corner[3] > 0 ? cy : cy - thick, length, thick), 0xFFFFFFFF);
					bitmap.fillRect(new Rectangle(corner[2] > 0 ? cx : cx - thick, corner[3] > 0 ? cy : cy - length, thick, length), 0xFFFFFFFF);
				}

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

	static function drawShape(shape:Shape, width:Int, height:Int):BitmapData
	{
		var bitmap:BitmapData = new BitmapData(width, height, true, 0);
		bitmap.draw(shape, null, null, null, null, true);
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
		TouchInput.laneRects = null;
		if (Controls.instance != null) Controls.instance.controllerMode = false;
		super.destroy();
	}
}
