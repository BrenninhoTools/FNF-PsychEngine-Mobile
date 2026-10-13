package mobile;

import flixel.FlxObject;
import flixel.FlxState;
import openfl.display.Shape;

typedef TouchStart =
{
	var x:Float;
	var y:Float;
	var time:Int;
	var onButton:Bool;
	var lastY:Float;
	var dragging:Bool;
}

class TouchInput
{
	public static inline final LANES:Int = 4;
	static inline final SWIPE_DISTANCE:Float = 70;
	static inline final TAP_DISTANCE:Float = 25;
	static inline final TAP_TIME:Int = 400;
	static inline final BUTTON_X:Float = 16;
	static inline final BUTTON_Y:Float = 16;
	static inline final BUTTON_SIZE:Float = 72;

	public static var hitboxEnabled:Bool = false;
	public static var blockGestures:Bool = false;
	public static var tapX(default, null):Float = 0;
	public static var tapY(default, null):Float = 0;

	static var lanePressed:Array<Bool> = [for (i in 0...LANES) false];
	static var lanePrevious:Array<Bool> = [for (i in 0...LANES) false];

	static var swipeUp:Bool = false;
	static var swipeDown:Bool = false;
	static var swipeLeft:Bool = false;
	static var swipeRight:Bool = false;
	static var tap:Bool = false;
	static var backTap:Bool = false;
	static var dragY:Float = 0;
	static var dragging:Bool = false;

	static var starts:Map<Int, TouchStart> = new Map();
	static var frame:Int = 0;
	static var computedFrame:Int = -1;

	static var button:Shape;
	static var buttonVisible:Bool = false;
	static var buttonPauseIcon:Bool = false;
	static var initialized:Bool = false;

	public static function init()
	{
		if (initialized) return;
		initialized = true;

		button = new Shape();
		button.visible = false;
		FlxG.stage.addChild(button);
		drawButton();

		FlxG.signals.preUpdate.add(function() frame++);
		FlxG.signals.postUpdate.add(function() {
			refresh();
			updateButton();
		});
	}

	public static function lanePressedAt(lane:Int):Bool
	{
		refresh();
		return lanePressed[lane];
	}

	public static function justPressed(key:String):Bool
	{
		refresh();
		var lane:Int = laneOf(key);
		if (lane > -1) return lanePressed[lane] && !lanePrevious[lane];

		if (key == 'back' || key == 'pause') return backTap;
		return !blockGestures && (justSwiped(key) || (key == 'accept' && tap));
	}

	public static function justSwiped(key:String):Bool
	{
		refresh();
		return switch (key)
		{
			case 'ui_up': swipeUp;
			case 'ui_down': swipeDown;
			case 'ui_left': swipeLeft;
			case 'ui_right': swipeRight;
			default: false;
		}
	}

	public static function justTapped():Bool
	{
		refresh();
		return tap;
	}

	public static function tappedOn(object:FlxObject, ?camera:FlxCamera, padding:Float = 0):Bool
	{
		return justTapped() && overlapsScreen(object, tapX, tapY, camera, padding);
	}

	public static function overlapsScreen(object:FlxObject, x:Float, y:Float, ?camera:FlxCamera, padding:Float = 0):Bool
	{
		if (object == null || !object.exists || !object.visible) return false;
		var pos:FlxPoint = object.getScreenPosition(null, camera != null ? camera : FlxG.camera);
		var hit:Bool = x >= pos.x - padding && x <= pos.x + object.width + padding && y >= pos.y - padding && y <= pos.y + object.height + padding;
		pos.put();
		return hit;
	}

	public static function dragDeltaY():Float
	{
		refresh();
		return dragY;
	}

	public static function isDragging():Bool
	{
		refresh();
		return dragging;
	}

	public static function pressed(key:String):Bool
	{
		refresh();
		var lane:Int = laneOf(key);
		return lane > -1 && lanePressed[lane];
	}

	public static function justReleased(key:String):Bool
	{
		refresh();
		var lane:Int = laneOf(key);
		return lane > -1 && !lanePressed[lane] && lanePrevious[lane];
	}

	public static function isNoteKey(key:String):Bool
	{
		return laneOf(key) > -1;
	}

	static function laneOf(key:String):Int
	{
		return switch (key)
		{
			case 'note_left': 0;
			case 'note_down': 1;
			case 'note_up': 2;
			case 'note_right': 3;
			default: -1;
		}
	}

	static function refresh()
	{
		if (computedFrame == frame) return;
		computedFrame = frame;

		for (i in 0...LANES)
		{
			lanePrevious[i] = lanePressed[i];
			lanePressed[i] = false;
		}
		swipeUp = swipeDown = swipeLeft = swipeRight = tap = backTap = dragging = false;
		dragY = 0;

		var activeIds:Array<Int> = [];
		for (touch in FlxG.touches.list)
		{
			var id:Int = touch.touchPointID;
			var x:Float = touch.screenX;
			var y:Float = touch.screenY;
			var onButton:Bool = buttonVisible && overButton(x, y);

			if (touch.justPressed)
				starts.set(id, {x: x, y: y, time: FlxG.game.ticks, onButton: onButton, lastY: y, dragging: false});

			var start:TouchStart = starts.get(id);
			if (start == null) continue;
			activeIds.push(id);

			if (touch.pressed && !start.onButton)
			{
				if (!start.dragging && Math.abs(y - start.y) > TAP_DISTANCE) start.dragging = true;
				if (start.dragging)
				{
					dragY += y - start.lastY;
					dragging = true;
				}
				start.lastY = y;
			}

			if (touch.pressed && hitboxEnabled && !start.onButton)
			{
				var lane:Int = Std.int(x / (FlxG.width / LANES));
				if (lane < 0) lane = 0;
				if (lane >= LANES) lane = LANES - 1;
				lanePressed[lane] = true;
			}

			if (touch.justReleased)
			{
				starts.remove(id);
				if (start.onButton)
				{
					if (onButton) backTap = true;
					continue;
				}

				var dx:Float = x - start.x;
				var dy:Float = y - start.y;
				var distance:Float = Math.sqrt(dx * dx + dy * dy);
				if (distance >= SWIPE_DISTANCE)
				{
					if (Math.abs(dx) > Math.abs(dy))
					{
						if (dx > 0) swipeRight = true;
						else swipeLeft = true;
					}
					else
					{
						if (dy > 0) swipeDown = true;
						else swipeUp = true;
					}
				}
				else if (distance <= TAP_DISTANCE && FlxG.game.ticks - start.time <= TAP_TIME)
				{
					tap = true;
					tapX = x;
					tapY = y;
				}
			}
		}

		for (id in [for (key in starts.keys()) key])
			if (!activeIds.contains(id)) starts.remove(id);

		#if android
		if (FlxG.android.justReleased.BACK) backTap = true;
		#end
	}

	static function overButton(x:Float, y:Float):Bool
	{
		return x >= BUTTON_X && x <= BUTTON_X + BUTTON_SIZE && y >= BUTTON_Y && y <= BUTTON_Y + BUTTON_SIZE;
	}

	static function updateButton()
	{
		var state:FlxState = FlxG.state;
		var visible:Bool = state != null && !Std.isOfType(state, CopyState) && !Std.isOfType(state, states.TitleState);
		buttonVisible = visible;
		button.visible = visible;
		if (!visible) return;

		var sub:FlxState = state.subState;
		var pauseIcon:Bool = Std.isOfType(state, PlayState) && (sub == null || Std.isOfType(sub, CustomFadeTransition));
		if (pauseIcon != buttonPauseIcon)
		{
			buttonPauseIcon = pauseIcon;
			drawButton();
		}

		var scaleX:Float = FlxG.scaleMode.scale.x;
		var scaleY:Float = FlxG.scaleMode.scale.y;
		button.x = FlxG.game.x + BUTTON_X * scaleX;
		button.y = FlxG.game.y + BUTTON_Y * scaleY;
		button.scaleX = scaleX;
		button.scaleY = scaleY;
		button.alpha = anyTouchOnButton() ? 0.9 : 0.55;
	}

	static function anyTouchOnButton():Bool
	{
		for (start in starts)
			if (start.onButton) return true;
		return false;
	}

	static function drawButton()
	{
		var g = button.graphics;
		var size:Float = BUTTON_SIZE;
		g.clear();
		g.beginFill(0x000000, 0.6);
		g.drawRoundRect(0, 0, size, size, 20, 20);
		g.endFill();
		g.beginFill(0xFFFFFF, 1);
		if (buttonPauseIcon)
		{
			g.drawRect(size * 0.3, size * 0.25, size * 0.14, size * 0.5);
			g.drawRect(size * 0.56, size * 0.25, size * 0.14, size * 0.5);
		}
		else
		{
			g.moveTo(size * 0.28, size * 0.5);
			g.lineTo(size * 0.62, size * 0.24);
			g.lineTo(size * 0.62, size * 0.76);
			g.lineTo(size * 0.28, size * 0.5);
		}
		g.endFill();
	}
}
