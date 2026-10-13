package mobile;

import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;

class EditorPad extends FlxSpriteGroup
{
	static inline final KEY_WIDTH:Int = 80;
	static inline final KEY_HEIGHT:Int = 48;
	static inline final GAP:Int = 6;
	static inline final MARGIN:Int = 8;

	static final STICKY:Array<FlxKey> = [SHIFT, CONTROL, ALT];
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
	var toggleButton:TouchButton;
	var keyButtons:Array<TouchButton> = [];
	var keyCodes:Array<FlxKey> = [];
	var heldKeys:Array<FlxKey> = [];
	var shown:Bool = false;
	var escapeQueued:Bool = false;

	public function new(rows:Array<String>)
	{
		super();

		padCamera = new FlxCamera();
		padCamera.bgColor.alpha = 0;
		FlxG.cameras.add(padCamera, false);

		toggleButton = new TouchButton(MARGIN, FlxG.height - KEY_HEIGHT - MARGIN, 'KEYS', KEY_WIDTH + 10, KEY_HEIGHT, 18);
		add(toggleButton);

		for (rowIndex in 0...rows.length)
		{
			var names:Array<String> = rows[rowIndex].split(' ');
			var y:Float = FlxG.height - MARGIN - (KEY_HEIGHT + GAP) * (rows.length - rowIndex + 1);
			for (column in 0...names.length)
			{
				var key:FlxKey = FlxKey.fromString(names[column]);
				if (key == NONE) continue;

				var label:String = LABELS.exists(names[column]) ? LABELS.get(names[column]) : names[column];
				var button:TouchButton = new TouchButton(MARGIN + column * (KEY_WIDTH + GAP), y, label, KEY_WIDTH, KEY_HEIGHT, 18);
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

	public function setSuspended(suspended:Bool)
	{
		toggleButton.visible = !suspended;
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

		if (toggleButton.justTapped)
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
		if (current == this) current = null;
		TouchInput.blockGestures = false;
		for (key in heldKeys.copy()) setKey(key, false);
		if (padCamera != null && FlxG.cameras.list.contains(padCamera))
			FlxG.cameras.remove(padCamera);
		padCamera = null;
		super.destroy();
	}
}
