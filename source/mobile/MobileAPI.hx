package mobile;

import flixel.FlxObject;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;
#if android
import lime.system.JNI;
#end

#if ios
@:cppFileCode('
extern "C" void psych_ios_keep_screen_on(int value);
extern "C" int psych_ios_battery_level(void);
extern "C" int psych_ios_is_charging(void);
extern "C" void psych_ios_vibrate(int duration);
')
#end
class MobileAPI
{
	static final LANE_KEYS:Array<String> = ['note_left', 'note_down', 'note_up', 'note_right'];
	static final SWIPES:Map<String, String> = ['up' => 'ui_up', 'down' => 'ui_down', 'left' => 'ui_left', 'right' => 'ui_right'];

	#if android
	static inline final UTIL:String = 'org/psychengine/mobile/MobileUtil';
	#end

	static var pad:VirtualPad;
	static var padCamera:FlxCamera;
	static var padHost:flixel.FlxState;
	static var padDispatchKeys:Bool = true;
	static var padCurrent:Map<String, Bool> = new Map();
	static var padPrevious:Map<String, Bool> = new Map();
	static var listening:Bool = false;

	public static function isMobile():Bool
	{
		return #if mobile true #else false #end;
	}

	public static function getPlatform():String
	{
		return #if android 'android' #elseif ios 'ios' #elseif windows 'windows' #elseif mac 'mac' #elseif linux 'linux' #else 'unknown' #end;
	}

	public static function vibrate(duration:Int = 100)
	{
		#if android
		JNI.createStaticMethod(UTIL, 'vibrate', '(I)V')(duration);
		#elseif ios
		untyped __cpp__('psych_ios_vibrate({0})', duration);
		#end
	}

	public static function toast(text:String, longDuration:Bool = false)
	{
		#if android
		JNI.createStaticMethod(UTIL, 'toast', '(Ljava/lang/String;Z)V')(text == null ? '' : text, longDuration);
		#end
	}

	public static function keepScreenOn(value:Bool = true)
	{
		#if android
		JNI.createStaticMethod(UTIL, 'keepScreenOn', '(Z)V')(value);
		#elseif ios
		untyped __cpp__('psych_ios_keep_screen_on({0})', value ? 1 : 0);
		#end
	}

	public static function getBatteryLevel():Int
	{
		#if android
		var level:Dynamic = JNI.createStaticMethod(UTIL, 'getBatteryLevel', '()I')();
		return level == null ? -1 : level;
		#elseif ios
		return untyped __cpp__('psych_ios_battery_level()');
		#else
		return -1;
		#end
	}

	public static function isCharging():Bool
	{
		#if android
		return JNI.createStaticMethod(UTIL, 'isCharging', '()Z')() == true;
		#elseif ios
		return untyped __cpp__('psych_ios_is_charging() != 0');
		#else
		return false;
		#end
	}

	public static function touchPressed():Bool
	{
		return #if mobile TouchInput.touchPressed() #else FlxG.mouse.pressed #end;
	}

	public static function touchJustPressed():Bool
	{
		return #if mobile TouchInput.touchJustPressed() #else FlxG.mouse.justPressed #end;
	}

	public static function touchJustReleased():Bool
	{
		return #if mobile TouchInput.touchJustReleased() #else FlxG.mouse.justReleased #end;
	}

	public static function touchTapped():Bool
	{
		return #if mobile TouchInput.justTapped() #else FlxG.mouse.justReleased #end;
	}

	public static function getTouchCount():Int
	{
		return #if mobile TouchInput.touchCount() #else (FlxG.mouse.pressed ? 1 : 0) #end;
	}

	public static function getTouchX(index:Int = 0):Float
	{
		return #if mobile TouchInput.getTouchX(index) #else FlxG.mouse.screenX #end;
	}

	public static function getTouchY(index:Int = 0):Float
	{
		return #if mobile TouchInput.getTouchY(index) #else FlxG.mouse.screenY #end;
	}

	public static function touchOverlaps(object:FlxObject, ?camera:FlxCamera):Bool
	{
		if (object == null) return false;
		#if mobile
		return TouchInput.touchOverlaps(object, camera);
		#else
		return FlxG.mouse.pressed && FlxG.mouse.overlaps(object, camera);
		#end
	}

	public static function touchJustTappedOn(object:FlxObject, ?camera:FlxCamera):Bool
	{
		if (object == null) return false;
		#if mobile
		return TouchInput.tappedOn(object, camera);
		#else
		return FlxG.mouse.justReleased && FlxG.mouse.overlaps(object, camera);
		#end
	}

	public static function swiped(direction:String):Bool
	{
		#if mobile
		var key:String = SWIPES.get(direction == null ? '' : direction.toLowerCase());
		return key != null && TouchInput.justSwiped(key);
		#else
		return false;
		#end
	}

	public static function hitboxPressed(lane:Int):Bool
	{
		#if mobile
		return lane >= 0 && lane < LANE_KEYS.length && TouchInput.pressed(LANE_KEYS[lane]);
		#else
		return false;
		#end
	}

	public static function hitboxJustPressed(lane:Int):Bool
	{
		#if mobile
		return lane >= 0 && lane < LANE_KEYS.length && TouchInput.justPressed(LANE_KEYS[lane]);
		#else
		return false;
		#end
	}

	public static function hitboxJustReleased(lane:Int):Bool
	{
		#if mobile
		return lane >= 0 && lane < LANE_KEYS.length && TouchInput.justReleased(LANE_KEYS[lane]);
		#else
		return false;
		#end
	}

	public static function setHitboxVisible(value:Bool)
	{
		#if mobile
		if (PlayState.instance != null && PlayState.instance.hitbox != null) PlayState.instance.hitbox.visible = value;
		#end
	}

	public static function setPauseButtonVisible(value:Bool)
	{
		#if mobile
		if (PlayState.instance != null && PlayState.instance.pauseButton != null) PlayState.instance.pauseButton.visible = value;
		#end
	}

	public static function getHitboxMode():String
	{
		return ClientPrefs.data.hitboxMode;
	}

	public static function getScreenStyle():String
	{
		return ClientPrefs.data.screenStyle;
	}

	public static function getWideOffset():Float
	{
		return WideScreen.offset;
	}

	public static function getStorageType():String
	{
		return #if mobile StorageUtil.getStorageType() #else 'Data' #end;
	}

	public static function getStoragePath():String
	{
		return #if mobile StorageUtil.getGameDir() #else haxe.io.Path.addTrailingSlash(Sys.getCwd()) #end;
	}

	public static function addVirtualPad(dpad:Bool = true, ?actions:Array<String>, dispatchKeys:Bool = true):Bool
	{
		removeVirtualPad();
		var keys:Array<FlxKey> = [];
		if (actions != null)
			for (name in actions)
			{
				var key:FlxKey = FlxKey.fromString(name == null ? '' : name.toUpperCase());
				if (key != NONE && !keys.contains(key)) keys.push(key);
			}

		var state:flixel.FlxState = FlxG.state;
		if (state == null) return false;
		while (state.subState != null) state = state.subState;

		padCamera = new FlxCamera();
		padCamera.bgColor.alpha = 0;
		FlxG.cameras.add(padCamera, false);

		padDispatchKeys = dispatchKeys;
		pad = new VirtualPad(dpad, keys);
		pad.cameras = [padCamera];
		pad.onKey = function(key:FlxKey, down:Bool)
		{
			if (padDispatchKeys)
				FlxG.stage.dispatchEvent(new KeyboardEvent(down ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP, true, false, 0, key));
		};
		state.add(pad);
		padHost = state;
		#if mobile
		TouchInput.blockGestures = true;
		#end

		padCurrent.clear();
		padPrevious.clear();
		if (!listening)
		{
			listening = true;
			FlxG.signals.preUpdate.add(updatePadState);
			FlxG.signals.preStateSwitch.add(removeVirtualPad);
		}
		return true;
	}

	public static function removeVirtualPad()
	{
		if (pad != null)
		{
			pad.releaseAll();
			if (padHost != null) padHost.remove(pad, true);
			padHost = null;
			pad.destroy();
			pad = null;
			#if mobile
			TouchInput.blockGestures = false;
			#end
		}
		if (padCamera != null)
		{
			if (FlxG.cameras.list.contains(padCamera)) FlxG.cameras.remove(padCamera);
			padCamera = null;
		}
		padCurrent.clear();
		padPrevious.clear();
	}

	public static function hasVirtualPad():Bool
	{
		return pad != null && pad.exists;
	}

	public static function setVirtualPadAlpha(alpha:Float)
	{
		if (pad != null) pad.alpha = alpha;
	}

	public static function setVirtualPadVisible(value:Bool)
	{
		if (pad == null) return;
		pad.visible = value;
		if (!value) pad.releaseAll();
	}

	static function updatePadState()
	{
		padPrevious = padCurrent.copy();
		padCurrent.clear();
		if (pad == null || !pad.exists) return;
		for (button in pad.buttons)
			if (button.pressed) padCurrent.set(button.key.toString(), true);
	}

	static function padKey(name:String):String
	{
		var key:FlxKey = FlxKey.fromString(name == null ? '' : name.toUpperCase());
		return key.toString();
	}

	public static function virtualPadPressed(name:String):Bool
	{
		return padCurrent.exists(padKey(name));
	}

	public static function virtualPadJustPressed(name:String):Bool
	{
		var key:String = padKey(name);
		return padCurrent.exists(key) && !padPrevious.exists(key);
	}

	public static function virtualPadJustReleased(name:String):Bool
	{
		var key:String = padKey(name);
		return !padCurrent.exists(key) && padPrevious.exists(key);
	}
}
