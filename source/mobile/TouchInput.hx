package mobile;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxState;
import openfl.display.Shape;

typedef TouchStart =
{
	var x:Float;
	var y:Float;
	var time:Int;
	var onOverlay:Bool;
	var button:MobileButton;
	var lastY:Float;
	var dragging:Bool;
}

class TouchInput
{
	public static inline final LANES:Int = 4;
	static inline final SWIPE_DISTANCE:Float = 70;
	static inline final TAP_DISTANCE:Float = 25;
	static inline final TAP_TIME:Int = 400;
	static inline final OVERLAY_X:Float = 16;
	static inline final OVERLAY_Y:Float = 16;
	static inline final OVERLAY_SIZE:Float = 72;

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
	static var tapConsumed:Bool = false;
	static var backTap:Bool = false;
	static var pauseTap:Bool = false;
	static var dragY:Float = 0;
	static var dragging:Bool = false;

	static var starts:Map<Int, TouchStart> = new Map();
	static var buttons:Array<MobileButton> = [];
	static var frame:Int = 0;
	static var computedFrame:Int = -1;

	static var overlay:Shape;
	static var overlayVisible:Bool = false;
	static var overlayPauseIcon:Bool = false;
	static var initialized:Bool = false;

	public static function init()
	{
		if (initialized) return;
		initialized = true;

		overlay = new Shape();
		overlay.visible = false;
		FlxG.stage.addChild(overlay);
		drawOverlay();

		FlxG.signals.preUpdate.add(function() frame++);
		FlxG.signals.postUpdate.add(function() {
			refresh();
			updateOverlay();
		});
	}

	public static function register(button:MobileButton)
	{
		if (!buttons.contains(button)) buttons.push(button);
	}

	public static function unregister(button:MobileButton)
	{
		buttons.remove(button);
		for (start in starts)
			if (start.button == button) start.button = null;
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

		return switch (key)
		{
			case 'back': backTap;
			case 'pause': pauseTap;
			case 'accept': !blockGestures && tap && !tapConsumed;
			default: !blockGestures && justSwiped(key);
		}
	}

	public static function pressed(key:String):Bool
	{
		refresh();
		var lane:Int = laneOf(key);
		if (lane > -1) return lanePressed[lane];
		return !blockGestures && justSwiped(key);
	}

	public static function justReleased(key:String):Bool
	{
		refresh();
		var lane:Int = laneOf(key);
		return lane > -1 && !lanePressed[lane] && lanePrevious[lane];
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

	public static function consumeTap()
	{
		refresh();
		tapConsumed = true;
	}

	public static function tappedOn(object:FlxObject, ?camera:FlxCamera, padding:Float = 0):Bool
	{
		return justTapped() && overlapsScreen(object, tapX, tapY, camera, padding);
	}

	public static function tappedRow(items:Array<FlxObject>, padding:Float = 10):Int
	{
		if (!justTapped()) return -1;
		for (i in 0...items.length)
		{
			var item:FlxObject = items[i];
			if (item == null || !item.exists || !item.visible) continue;
			var pos:FlxPoint = item.getScreenPosition(null, cameraOf(item, null));
			var hit:Bool = tapY >= pos.y - padding && tapY <= pos.y + item.height + padding;
			pos.put();
			if (hit) return i;
		}
		return -1;
	}

	public static function overlapsScreen(object:FlxObject, x:Float, y:Float, ?camera:FlxCamera, padding:Float = 0):Bool
	{
		if (object == null || !object.exists || !object.visible) return false;
		var pos:FlxPoint = object.getScreenPosition(null, cameraOf(object, camera));
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

	public static function isNoteKey(key:String):Bool
	{
		return laneOf(key) > -1;
	}

	static function cameraOf(object:FlxBasic, camera:FlxCamera):FlxCamera
	{
		if (camera != null) return camera;
		var cams:Array<FlxCamera> = object.cameras;
		return (cams != null && cams.length > 0) ? cams[0] : FlxG.camera;
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

	static function buttonEnabled(button:MobileButton):Bool
	{
		if (button == null || !button.exists || !button.alive) return false;
		if (button.key == 'pause')
		{
			var sub:FlxState = FlxG.state != null ? FlxG.state.subState : null;
			button.visible = sub == null || Std.isOfType(sub, CustomFadeTransition);
		}
		return button.visible;
	}

	static function buttonAt(x:Float, y:Float):MobileButton
	{
		var i:Int = buttons.length - 1;
		while (i >= 0)
		{
			var button:MobileButton = buttons[i];
			if (buttonEnabled(button) && overlapsScreen(button, x, y)) return button;
			i--;
		}
		return null;
	}

	static function anyButtonEnabled():Bool
	{
		for (button in buttons)
			if (buttonEnabled(button)) return true;
		return false;
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
		swipeUp = swipeDown = swipeLeft = swipeRight = tap = tapConsumed = backTap = pauseTap = dragging = false;
		dragY = 0;

		var activeIds:Array<Int> = [];
		for (touch in FlxG.touches.list)
		{
			var id:Int = touch.touchPointID;
			var x:Float = touch.screenX;
			var y:Float = touch.screenY;

			if (touch.justPressed)
			{
				var button:MobileButton = buttonAt(x, y);
				var onOverlay:Bool = button == null && overlayVisible && overOverlay(x, y);
				if (button != null) button.press();
				starts.set(id, {x: x, y: y, time: FlxG.game.ticks, onOverlay: onOverlay, button: button, lastY: y, dragging: false});
			}

			var start:TouchStart = starts.get(id);
			if (start == null) continue;
			activeIds.push(id);

			var onControl:Bool = start.onOverlay || start.button != null;
			if (touch.pressed && !onControl)
			{
				if (!start.dragging && Math.abs(y - start.y) > TAP_DISTANCE) start.dragging = true;
				if (start.dragging)
				{
					dragY += y - start.lastY;
					dragging = true;
				}
				start.lastY = y;

				if (hitboxEnabled)
				{
					var lane:Int = Std.int(x / (FlxG.width / LANES));
					if (lane < 0) lane = 0;
					if (lane >= LANES) lane = LANES - 1;
					lanePressed[lane] = true;
				}
			}

			if (touch.justReleased)
			{
				starts.remove(id);
				if (start.button != null)
				{
					if (buttonEnabled(start.button) && overlapsScreen(start.button, x, y))
					{
						if (start.button.key == 'pause') pauseTap = true;
						else backTap = true;
					}
					continue;
				}
				if (start.onOverlay)
				{
					if (overOverlay(x, y)) backTap = pauseTap = true;
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
		if (FlxG.android.justReleased.BACK) backTap = pauseTap = true;
		#end
	}

	static function overOverlay(x:Float, y:Float):Bool
	{
		return x >= OVERLAY_X && x <= OVERLAY_X + OVERLAY_SIZE && y >= OVERLAY_Y && y <= OVERLAY_Y + OVERLAY_SIZE;
	}

	static function updateOverlay()
	{
		var state:FlxState = FlxG.state;
		var visible:Bool = state != null && !Std.isOfType(state, CopyState) && !Std.isOfType(state, states.TitleState) && !anyButtonEnabled();
		overlayVisible = visible;
		overlay.visible = visible;
		if (!visible) return;

		var sub:FlxState = state.subState;
		var pauseIcon:Bool = Std.isOfType(state, PlayState) && (sub == null || Std.isOfType(sub, CustomFadeTransition));
		if (pauseIcon != overlayPauseIcon)
		{
			overlayPauseIcon = pauseIcon;
			drawOverlay();
		}

		var scaleX:Float = FlxG.scaleMode.scale.x;
		var scaleY:Float = FlxG.scaleMode.scale.y;
		overlay.x = FlxG.game.x + OVERLAY_X * scaleX;
		overlay.y = FlxG.game.y + OVERLAY_Y * scaleY;
		overlay.scaleX = scaleX;
		overlay.scaleY = scaleY;

		var held:Bool = false;
		for (start in starts)
			if (start.onOverlay) held = true;
		overlay.alpha = held ? 0.9 : 0.55;
	}

	static function drawOverlay()
	{
		var g = overlay.graphics;
		var size:Float = OVERLAY_SIZE;
		g.clear();
		g.beginFill(0x000000, 0.6);
		g.drawRoundRect(0, 0, size, size, 20, 20);
		g.endFill();
		g.beginFill(0xFFFFFF, 1);
		if (overlayPauseIcon)
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
