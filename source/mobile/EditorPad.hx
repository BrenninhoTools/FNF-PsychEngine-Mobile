package mobile;

import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;

class EditorPad extends FlxSpriteGroup
{
	static inline final KEY_WIDTH:Int = 80;
	static inline final KEY_HEIGHT:Int = 48;
	static inline final GAP:Int = 6;
	static inline final MARGIN:Int = 8;

	static final STICKY:Array<FlxKey> = [SHIFT, CONTROL, ALT];
	static final DPAD_KEYS:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	static final ACTION_KEYS:Array<String> = ['ESCAPE', 'ENTER', 'SPACE'];
	static final LABELS:Map<String, String> = [
		'ESCAPE' => 'ESC',
		'CONTROL' => 'CTRL',
		'BACKSPACE' => 'BKSP',
		'DELETE' => 'DEL',
		'LEFT' => '<',
		'RIGHT' => '>',
		'UP' => '^',
		'DOWN' => 'v',
		'LBRACKET' => '[',
		'RBRACKET' => ']'
	];

	public static var current(default, null):EditorPad;

	var padCamera:FlxCamera;
	var virtualPad:VirtualPad;
	var toggleButton:TouchButton;
	var keyButtons:Array<TouchButton> = [];
	var keyCodes:Array<FlxKey> = [];
	var heldKeys:Array<FlxKey> = [];
	var shown:Bool = false;
	var escapeQueued:Bool = false;

	public var pinchZoom:Bool = false;
	public var minZoom:Float = 0.1;
	public var maxZoom:Float = 3;

	var panButton:TouchButton;
	var hideButton:TouchButton;
	var panMode:Bool = false;
	var hidden:Bool = false;
	var rightDown:Bool = false;
	var gestureDistance:Float = -1;
	var gestureX:Float = 0;
	var gestureY:Float = 0;
	var wheelAccum:Float = 0;

	public function new(rows:Array<String>)
	{
		super();

		padCamera = new FlxCamera();
		padCamera.bgColor.alpha = 0;
		FlxG.cameras.add(padCamera, false);

		var names:Array<String> = [for (row in rows) for (name in row.split(' ')) name];
		var hasDpad:Bool = false;
		for (name in DPAD_KEYS) if (names.contains(name)) hasDpad = true;
		var actions:Array<FlxKey> = [for (name in ACTION_KEYS) if (names.contains(name)) FlxKey.fromString(name)];

		virtualPad = new VirtualPad(hasDpad, actions);
		virtualPad.onKey = setKey;
		add(virtualPad);

		var keyRows:Array<Array<String>> = [];
		for (row in rows)
		{
			var keys:Array<String> = [for (name in row.split(' ')) if (name.length > 0 && !(hasDpad && DPAD_KEYS.contains(name)) && !ACTION_KEYS.contains(name)) name];
			if (keys.length > 0) keyRows.push(keys);
		}

		var toggleWidth:Int = KEY_WIDTH + 10;
		toggleButton = new TouchButton((FlxG.width - toggleWidth) / 2, FlxG.height - KEY_HEIGHT - MARGIN, 'KEYS', toggleWidth, KEY_HEIGHT, 18);
		toggleButton.useImage(keyImage('keys'));
		toggleButton.visible = keyRows.length > 0;
		add(toggleButton);

		panButton = new TouchButton(toggleButton.x - toggleWidth - GAP, toggleButton.y, 'PAN', toggleWidth, KEY_HEIGHT, 18);
		panButton.useImage(keyImage('pan'));
		add(panButton);

		hideButton = new TouchButton(toggleButton.x + toggleWidth + GAP, toggleButton.y, 'HIDE', toggleWidth, KEY_HEIGHT, 18);
		hideButton.useImage(keyImage('hide'));
		add(hideButton);

		FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 999);
		FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 999);

		for (rowIndex in 0...keyRows.length)
		{
			var keys:Array<String> = keyRows[rowIndex];
			var rowWidth:Float = keys.length * KEY_WIDTH + (keys.length - 1) * GAP;
			var startX:Float = (FlxG.width - rowWidth) / 2;
			var y:Float = FlxG.height - MARGIN - (KEY_HEIGHT + GAP) * (keyRows.length - rowIndex + 1);
			for (column in 0...keys.length)
			{
				var key:FlxKey = FlxKey.fromString(keys[column]);
				if (key == NONE) continue;

				var label:String = LABELS.exists(keys[column]) ? LABELS.get(keys[column]) : keys[column];
				var button:TouchButton = new TouchButton(startX + column * (KEY_WIDTH + GAP), y, label, KEY_WIDTH, KEY_HEIGHT, 18);
				button.useImage(keyImage(keys[column]));
				button.visible = false;
				if (!STICKY.contains(key))
				{
					button.onPress = function() setKey(key, true);
					button.onRelease = function() setKey(key, false);
				}
				keyButtons.push(button);
				keyCodes.push(key);
				add(button);
			}
		}

		cameras = [padCamera];
		TouchInput.blockGestures = true;
		current = this;
	}

	static function keyImage(name:String):flixel.graphics.FlxGraphic
	{
		return Paths.image('mobile/virtualpad/keys/' + name.toLowerCase());
	}

	function onMouseDown(e:MouseEvent)
	{
		if (!panMode) return;
		e.stopImmediatePropagation();
		rightDown = true;
		FlxG.stage.dispatchEvent(new MouseEvent(MouseEvent.RIGHT_MOUSE_DOWN, true, false, e.localX, e.localY));
	}

	function onMouseUp(e:MouseEvent)
	{
		if (!rightDown) return;
		e.stopImmediatePropagation();
		rightDown = false;
		FlxG.stage.dispatchEvent(new MouseEvent(MouseEvent.RIGHT_MOUSE_UP, true, false, e.localX, e.localY));
	}

	function setPanMode(value:Bool)
	{
		panMode = value;
		panButton.toggled = value;
		if (!value && rightDown)
		{
			rightDown = false;
			FlxG.stage.dispatchEvent(new MouseEvent(MouseEvent.RIGHT_MOUSE_UP, true, false, 0, 0));
		}
	}

	function setHidden(value:Bool)
	{
		hidden = value;
		hideButton.toggled = value;
		virtualPad.visible = !value;
		virtualPad.releaseAll();
		toggleButton.visible = !value && keyButtons.length > 0;
		panButton.visible = !value;
		for (button in keyButtons) button.visible = shown && !value;
		hideButton.alpha = value ? 0.5 : 1;
	}

	function updateGestures()
	{
		var touches:Array<Array<Float>> = TouchInput.touchPositions(true);
		if (touches.length < 2)
		{
			gestureDistance = -1;
			wheelAccum = 0;
			return;
		}

		var dx:Float = touches[1][0] - touches[0][0];
		var dy:Float = touches[1][1] - touches[0][1];
		var distance:Float = Math.sqrt(dx * dx + dy * dy);
		var midX:Float = (touches[0][0] + touches[1][0]) / 2;
		var midY:Float = (touches[0][1] + touches[1][1]) / 2;

		if (gestureDistance < 0)
		{
			gestureDistance = distance;
			gestureX = midX;
			gestureY = midY;
			return;
		}

		var camera:FlxCamera = FlxG.camera;
		if (pinchZoom && camera != null)
		{
			if (gestureDistance > 0 && distance > 0)
				camera.zoom = FlxMath.bound(camera.zoom * (distance / gestureDistance), minZoom, maxZoom);
			camera.scroll.x -= (midX - gestureX) / camera.zoom;
			camera.scroll.y -= (midY - gestureY) / camera.zoom;
		}
		else
		{
			wheelAccum += midY - gestureY;
			while (Math.abs(wheelAccum) >= 36)
			{
				var delta:Int = wheelAccum > 0 ? 1 : -1;
				wheelAccum -= delta * 36;
				FlxG.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_WHEEL, true, false, 0, 0, null, false, false, false, false, delta));
			}
		}

		gestureDistance = distance;
		gestureX = midX;
		gestureY = midY;
	}

	public function setSuspended(suspended:Bool)
	{
		if (suspended)
		{
			setPanMode(false);
			setHidden(false);
		}
		panButton.visible = hideButton.visible = !suspended;
		toggleButton.visible = !suspended && keyButtons.length > 0;
		virtualPad.visible = !suspended;
		virtualPad.releaseAll();
		for (button in keyButtons) button.visible = shown && !suspended;
		for (key in heldKeys.copy()) setKey(key, false);
		for (i in 0...keyButtons.length)
			if (STICKY.contains(keyCodes[i])) keyButtons[i].toggled = false;
		TouchInput.blockGestures = !suspended;
	}

	override function update(elapsed:Float)
	{
		if (escapeQueued)
		{
			escapeQueued = false;
			setKey(ESCAPE, false);
		}

		super.update(elapsed);

		if (hideButton.visible && hideButton.justTapped) setHidden(!hidden);
		if (panButton.visible && panButton.justTapped) setPanMode(!panMode);
		if (hideButton.visible) updateGestures();

		if (toggleButton.visible && toggleButton.justTapped)
		{
			shown = !shown;
			for (button in keyButtons) button.visible = shown;
			toggleButton.toggled = shown;
		}

		for (i in 0...keyButtons.length)
		{
			var key:FlxKey = keyCodes[i];
			if (STICKY.contains(key) && keyButtons[i].justTapped)
			{
				keyButtons[i].toggled = !keyButtons[i].toggled;
				setKey(key, keyButtons[i].toggled);
			}
		}

		#if android
		if (FlxG.android.justReleased.BACK)
		{
			setKey(ESCAPE, true);
			escapeQueued = true;
		}
		#end
	}

	function setKey(key:FlxKey, down:Bool)
	{
		if (down == heldKeys.contains(key)) return;
		if (down) heldKeys.push(key);
		else heldKeys.remove(key);
		FlxG.stage.dispatchEvent(new KeyboardEvent(down ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP, true, false, 0, key));
	}

	override function destroy()
	{
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
		if (rightDown) FlxG.stage.dispatchEvent(new MouseEvent(MouseEvent.RIGHT_MOUSE_UP, true, false, 0, 0));
		if (current == this) current = null;
		TouchInput.blockGestures = false;
		for (key in heldKeys.copy()) setKey(key, false);
		if (padCamera != null && FlxG.cameras.list.contains(padCamera))
			FlxG.cameras.remove(padCamera);
		padCamera = null;
		super.destroy();
	}
}
