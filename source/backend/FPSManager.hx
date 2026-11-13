package backend;

import openfl.Lib;

class FPSManager
{
	public static inline final OFF:String = 'Off';
	public static inline final UNLOCKED:String = 'Unlocked';
	public static inline final DISPLAY:String = 'Display';
	public static inline final ADAPTIVE:String = 'Adaptive';
	public static final MODES:Array<String> = [OFF, UNLOCKED, DISPLAY, ADAPTIVE];

	static final STEPS:Array<Int> = [30, 48, 60, 75, 90, 120, 144, 165, 240, 360];
	static inline final MIN_FPS:Int = 30;
	static inline final UNLOCKED_LIMIT:Int = 1000;
	static inline final BACKGROUND_FPS:Int = 30;
	static inline final SAMPLE_TIME:Float = 1;
	static inline final DROP_SAMPLES:Int = 2;
	static inline final RAISE_SAMPLES:Int = 5;

	public static var target(default, null):Int = 60;
	public static var measuredFPS(default, null):Float = 0;

	static var initialized:Bool = false;
	static var focused:Bool = true;
	static var frames:Int = 0;
	static var sampleStart:Float = 0;
	static var lowSamples:Int = 0;
	static var highSamples:Int = 0;
	static var lastDisplayRate:Int = 0;

	public static function mode():String
	{
		var value:String = ClientPrefs.data.fpsRework;
		return MODES.contains(value) ? value : OFF;
	}

	public static function displayRate():Int
	{
		var rate:Int = 0;
		try
		{
			var window = FlxG.stage.application.window;
			if (window != null && window.displayMode != null) rate = window.displayMode.refreshRate;
		}
		catch (e:Dynamic) {}
		return rate > 0 ? rate : 60;
	}

	public static function describe():String
	{
		return switch (mode())
		{
			case UNLOCKED: 'Unlocked';
			case DISPLAY: 'Display ($target)';
			case ADAPTIVE: 'Adaptive ($target)';
			default: '';
		}
	}

	public static function warningFPS():Float
	{
		return (mode() == UNLOCKED ? displayRate() : target) * 0.5;
	}

	public static function apply()
	{
		init();
		lastDisplayRate = displayRate();
		target = switch (mode())
		{
			case UNLOCKED: UNLOCKED_LIMIT;
			case DISPLAY, ADAPTIVE: Std.int(Math.max(MIN_FPS, lastDisplayRate));
			default: ClientPrefs.data.framerate;
		}
		resetSamples();
		refreshFramerate();
	}

	static function init()
	{
		if (initialized || FlxG.signals == null) return;
		initialized = true;
		FlxG.signals.postDraw.add(onDraw);
		FlxG.signals.postStateSwitch.add(resetSamples);
		FlxG.signals.focusLost.add(function() {
			focused = false;
			refreshFramerate();
		});
		FlxG.signals.focusGained.add(function() {
			focused = true;
			resetSamples();
			refreshFramerate();
		});
	}

	static function refreshFramerate()
	{
		var fps:Int = target;
		if (!focused && mode() != OFF) fps = Std.int(Math.min(fps, BACKGROUND_FPS));
		setFramerate(fps);
	}

	static function setFramerate(fps:Int)
	{
		if (fps > FlxG.drawFramerate)
		{
			FlxG.updateFramerate = fps;
			FlxG.drawFramerate = fps;
		}
		else
		{
			FlxG.drawFramerate = fps;
			FlxG.updateFramerate = fps;
		}
	}

	static function resetSamples()
	{
		frames = 0;
		sampleStart = Lib.getTimer();
		lowSamples = 0;
		highSamples = 0;
	}

	static function onDraw()
	{
		frames++;
		var now:Float = Lib.getTimer();
		var elapsed:Float = (now - sampleStart) / 1000;
		if (elapsed < SAMPLE_TIME) return;

		var hitch:Bool = elapsed > SAMPLE_TIME * 2;
		measuredFPS = frames / elapsed;
		frames = 0;
		sampleStart = now;
		if (!focused || hitch) return;

		switch (mode())
		{
			case DISPLAY:
				if (displayRate() != lastDisplayRate) apply();
			case ADAPTIVE:
				if (displayRate() != lastDisplayRate) apply();
				else adapt();
			default:
		}
	}

	static function adapt()
	{
		var limit:Int = Std.int(Math.max(MIN_FPS, lastDisplayRate));
		if (measuredFPS < target * 0.85)
		{
			highSamples = 0;
			if (++lowSamples >= DROP_SAMPLES)
			{
				lowSamples = 0;
				var lower:Int = MIN_FPS;
				for (step in STEPS)
					if (step < target && step >= measuredFPS * 0.9) { lower = step; break; }
				if (lower < target)
				{
					target = lower;
					refreshFramerate();
				}
			}
		}
		else if (measuredFPS >= target * 0.95 && target < limit)
		{
			lowSamples = 0;
			if (++highSamples >= RAISE_SAMPLES)
			{
				highSamples = 0;
				var higher:Int = limit;
				for (step in STEPS)
					if (step > target && step <= limit) { higher = step; break; }
				target = higher;
				refreshFramerate();
			}
		}
		else lowSamples = highSamples = 0;
	}
}
