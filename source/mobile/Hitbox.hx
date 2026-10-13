package mobile;

import openfl.geom.Rectangle;

class Hitbox extends FlxSpriteGroup
{
	static final COLORS:Array<FlxColor> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
	static inline final BORDER:Int = 6;
	static inline final IDLE_ALPHA:Float = 0.12;
	static inline final PRESSED_ALPHA:Float = 0.55;

	var lanes:Array<FlxSprite> = [];

	public function new()
	{
		super();

		var laneWidth:Int = Std.int(FlxG.width / TouchInput.LANES);
		for (i in 0...TouchInput.LANES)
		{
			var lane:FlxSprite = new FlxSprite(i * laneWidth, 0);
			lane.makeGraphic(laneWidth, FlxG.height, FlxColor.WHITE, true);
			lane.pixels.fillRect(new Rectangle(BORDER, BORDER, laneWidth - BORDER * 2, FlxG.height - BORDER * 2), 0x40FFFFFF);
			lane.color = COLORS[i % COLORS.length];
			lane.alpha = IDLE_ALPHA;
			lane.antialiasing = false;
			lanes.push(lane);
			add(lane);
		}

		scrollFactor.set();
		visible = ClientPrefs.data.hitboxVisible;
		TouchInput.hitboxEnabled = true;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var lerp:Float = Math.min(1, elapsed * 18);
		for (i in 0...lanes.length)
		{
			var target:Float = TouchInput.lanePressedAt(i) ? PRESSED_ALPHA : IDLE_ALPHA;
			lanes[i].alpha += (target - lanes[i].alpha) * lerp;
		}
	}

	override function destroy()
	{
		TouchInput.hitboxEnabled = false;
		if (Controls.instance != null) Controls.instance.controllerMode = false;
		super.destroy();
	}
}
