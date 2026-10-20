package mobile;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.TouchEvent;

typedef CursorPoint = {
	x:Float,
	y:Float,
	life:Float,
	held:Bool
}

class TouchCursor extends Sprite
{
	static inline final RADIUS:Float = 30;
	static inline final FADE_TIME:Float = 0.25;

	public static var instance(default, null):TouchCursor;

	var points:Map<Int, CursorPoint> = new Map();
	var lastTime:Int = 0;

	public static function init()
	{
		if (instance != null) return;
		instance = new TouchCursor();
		Lib.current.stage.addChild(instance);
	}

	public function new()
	{
		super();
		mouseEnabled = false;
		mouseChildren = false;

		var stage = Lib.current.stage;
		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouch);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouch);
		stage.addEventListener(TouchEvent.TOUCH_END, onRelease);
		addEventListener(Event.ENTER_FRAME, onFrame);
		lastTime = Lib.getTimer();
	}

	function onTouch(e:TouchEvent)
	{
		var point:CursorPoint = points.get(e.touchPointID);
		if (point == null)
		{
			point = {x: e.stageX, y: e.stageY, life: 1, held: true};
			points.set(e.touchPointID, point);
		}
		point.x = e.stageX;
		point.y = e.stageY;
		point.life = 1;
		point.held = true;
	}

	function onRelease(e:TouchEvent)
	{
		var point:CursorPoint = points.get(e.touchPointID);
		if (point == null) return;
		point.x = e.stageX;
		point.y = e.stageY;
		point.held = false;
	}

	function onFrame(_)
	{
		var now:Int = Lib.getTimer();
		var elapsed:Float = Math.min(0.1, (now - lastTime) / 1000);
		lastTime = now;

		if (parent != null && parent.getChildIndex(this) != parent.numChildren - 1)
			parent.setChildIndex(this, parent.numChildren - 1);

		graphics.clear();
		if (!ClientPrefs.data.touchCursor)
		{
			points.clear();
			return;
		}

		var scale:Float = 1;
		if (FlxG.scaleMode != null) scale = Math.max(0.5, Math.min(FlxG.scaleMode.scale.x, FlxG.scaleMode.scale.y));

		for (id in [for (key in points.keys()) key])
		{
			var point:CursorPoint = points.get(id);
			if (!point.held)
			{
				point.life -= elapsed / FADE_TIME;
				if (point.life <= 0)
				{
					points.remove(id);
					continue;
				}
			}

			var grow:Float = point.held ? 1 : 1 + (1 - point.life) * 0.6;
			var radius:Float = RADIUS * scale * grow;
			graphics.lineStyle(3 * scale, 0xFFFFFF, 0.85 * point.life);
			graphics.beginFill(0xFFFFFF, 0.22 * point.life);
			graphics.drawCircle(point.x, point.y, radius);
			graphics.endFill();
			graphics.lineStyle(0, 0, 0);
			graphics.beginFill(0xFFFFFF, 0.9 * point.life);
			graphics.drawCircle(point.x, point.y, 5 * scale);
			graphics.endFill();
		}
	}
}
