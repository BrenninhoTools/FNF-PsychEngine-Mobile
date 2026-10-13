package mobile;

import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxState;
import openfl.events.MouseEvent;
import openfl.events.TouchEvent;

typedef TouchStart =
{
	var x:Float;
	var y:Float;
	var time:Int;
	var button:MobileButton;
	var control:FlxObject;
	var lastY:Float;
	var dragging:Bool;
}

class TouchInput
{
	public static inline final LANES:Int = 4;
	static inline final SWIPE_DISTANCE:Float = 70;
	static inline final TAP_DISTANCE:Float = 25;
	static inline final TAP_TIME:Int = 400;

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
	static var tappedControls:Array<FlxObject> = [];
	static var heldControls:Array<FlxObject> = [];

	static var starts:Map<Int, TouchStart> = new Map();
	static var buttons:Array<MobileButton> = [];
	static var controls:Array<FlxObject> = [];
	static var frame:Int = 0;
	static var computedFrame:Int = -1;

	static var activeTouches:Int = 0;
	static var primaryBlocked:Bool = false;
	static var initialized:Bool = false;

	public static function init()
	{
		if (initialized) return;
		initialized = true;

		FlxG.stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin, false, 1000);
		FlxG.stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd, false, 1000);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseEvent, false, 1000);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseEvent, false, 1000);

		FlxG.signals.preUpdate.add(function() frame++);
		FlxG.signals.postUpdate.add(refresh);
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

	public static function addControl(control:FlxObject)
	{
		if (!controls.contains(control)) controls.push(control);
	}

	public static function removeControl(control:FlxObject)
	{
		controls.remove(control);
		heldControls.remove(control);
		tappedControls.remove(control);
		for (start in starts)
			if (start.control == control) start.control = null;
	}

	public static function controlTapped(control:FlxObject):Bool
	{
		refresh();
		return tappedControls.contains(control);
	}

	public static function controlHeld(control:FlxObject):Bool
	{
		refresh();
		return heldControls.contains(control);
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
			var bounds:Array<Float> = screenBounds(item, null);
			if (tapY >= bounds[1] - padding && tapY <= bounds[1] + bounds[3] + padding) return i;
		}
		return -1;
	}

	public static function overlapsScreen(object:FlxObject, x:Float, y:Float, ?camera:FlxCamera, padding:Float = 0):Bool
	{
		if (object == null || !object.exists || !object.visible) return false;
		var bounds:Array<Float> = screenBounds(object, camera);
		return x >= bounds[0] - padding && x <= bounds[0] + bounds[2] + padding && y >= bounds[1] - padding && y <= bounds[1] + bounds[3] + padding;
	}

	static function screenBounds(object:FlxObject, camera:FlxCamera):Array<Float>
	{
		var cam:FlxCamera = cameraOf(object, camera);
		var pos:FlxPoint = object.getScreenPosition(null, cam);
		var marginX:Float = cam.width * 0.5 * (1 - 1 / cam.zoom);
		var marginY:Float = cam.height * 0.5 * (1 - 1 / cam.zoom);
		var bounds:Array<Float> = [cam.x + (pos.x - marginX) * cam.zoom, cam.y + (pos.y - marginY) * cam.zoom, object.width * cam.zoom, object.height * cam.zoom];
		pos.put();
		return bounds;
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

	static function controlAt(x:Float, y:Float):FlxObject
	{
		var i:Int = controls.length - 1;
		while (i >= 0)
		{
			var control:FlxObject = controls[i];
			if (control != null && control.exists && control.alive && overlapsScreen(control, x, y)) return control;
			i--;
		}
		return null;
	}

	static function onTouchBegin(e:TouchEvent)
	{
		if (FlxG.game == null || FlxG.scaleMode == null) return;
		var x:Float = (e.stageX - FlxG.game.x) / FlxG.scaleMode.scale.x;
		var y:Float = (e.stageY - FlxG.game.y) / FlxG.scaleMode.scale.y;
		var onControl:Bool = buttonAt(x, y) != null || controlAt(x, y) != null;
		if (activeTouches == 0) primaryBlocked = onControl;
		activeTouches++;
	}

	static function onTouchEnd(e:TouchEvent)
	{
		if (activeTouches > 0) activeTouches--;
	}

	static function onMouseEvent(e:MouseEvent)
	{
		if (primaryBlocked) e.stopImmediatePropagation();
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
		tappedControls.resize(0);
		heldControls.resize(0);

		var activeIds:Array<Int> = [];
		for (touch in FlxG.touches.list)
		{
			var id:Int = touch.touchPointID;
			var x:Float = touch.screenX;
			var y:Float = touch.screenY;

			if (touch.justPressed)
			{
				var button:MobileButton = buttonAt(x, y);
				var control:FlxObject = button == null ? controlAt(x, y) : null;
				if (button != null) button.press();
				starts.set(id, {x: x, y: y, time: FlxG.game.ticks, button: button, control: control, lastY: y, dragging: false});
			}

			var start:TouchStart = starts.get(id);
			if (start == null) continue;
			activeIds.push(id);

			if (start.control != null)
			{
				if (touch.pressed && !heldControls.contains(start.control)) heldControls.push(start.control);
				if (touch.justReleased)
				{
					if (overlapsScreen(start.control, x, y)) tappedControls.push(start.control);
					starts.remove(id);
				}
				continue;
			}

			if (touch.pressed && start.button == null)
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
}
