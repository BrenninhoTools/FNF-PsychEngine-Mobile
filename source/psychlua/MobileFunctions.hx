package psychlua;

import flixel.FlxObject;
import mobile.MobileAPI;

class MobileFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;

		Lua_helper.add_callback(lua, "isMobile", MobileAPI.isMobile);
		Lua_helper.add_callback(lua, "getPlatform", MobileAPI.getPlatform);
		Lua_helper.add_callback(lua, "vibrate", function(?duration:Int = 100) MobileAPI.vibrate(duration));
		Lua_helper.add_callback(lua, "mobileToast", function(text:String, ?longDuration:Bool = false) MobileAPI.toast(text, longDuration));
		Lua_helper.add_callback(lua, "keepScreenOn", function(?value:Bool = true) MobileAPI.keepScreenOn(value));
		Lua_helper.add_callback(lua, "getBatteryLevel", MobileAPI.getBatteryLevel);
		Lua_helper.add_callback(lua, "isCharging", MobileAPI.isCharging);

		Lua_helper.add_callback(lua, "touchPressed", MobileAPI.touchPressed);
		Lua_helper.add_callback(lua, "touchJustPressed", MobileAPI.touchJustPressed);
		Lua_helper.add_callback(lua, "touchJustReleased", MobileAPI.touchJustReleased);
		Lua_helper.add_callback(lua, "touchTapped", MobileAPI.touchTapped);
		Lua_helper.add_callback(lua, "getTouchCount", MobileAPI.getTouchCount);
		Lua_helper.add_callback(lua, "getTouchX", function(?index:Int = 0) return MobileAPI.getTouchX(index));
		Lua_helper.add_callback(lua, "getTouchY", function(?index:Int = 0) return MobileAPI.getTouchY(index));
		Lua_helper.add_callback(lua, "touchOverlaps", function(obj:String, ?camera:String = '') {
			return MobileAPI.touchOverlaps(findObject(obj), cameraFrom(camera));
		});
		Lua_helper.add_callback(lua, "touchJustTappedOn", function(obj:String, ?camera:String = '') {
			return MobileAPI.touchJustTappedOn(findObject(obj), cameraFrom(camera));
		});
		Lua_helper.add_callback(lua, "swiped", function(direction:String) return MobileAPI.swiped(direction));

		Lua_helper.add_callback(lua, "hitboxPressed", function(lane:Int) return MobileAPI.hitboxPressed(lane));
		Lua_helper.add_callback(lua, "hitboxJustPressed", function(lane:Int) return MobileAPI.hitboxJustPressed(lane));
		Lua_helper.add_callback(lua, "hitboxJustReleased", function(lane:Int) return MobileAPI.hitboxJustReleased(lane));
		Lua_helper.add_callback(lua, "setHitboxVisible", function(value:Bool) MobileAPI.setHitboxVisible(value));
		Lua_helper.add_callback(lua, "setPauseButtonVisible", function(value:Bool) MobileAPI.setPauseButtonVisible(value));
		Lua_helper.add_callback(lua, "getHitboxMode", MobileAPI.getHitboxMode);
		Lua_helper.add_callback(lua, "getScreenStyle", MobileAPI.getScreenStyle);
		Lua_helper.add_callback(lua, "getWideOffset", MobileAPI.getWideOffset);
		Lua_helper.add_callback(lua, "getStorageType", MobileAPI.getStorageType);
		Lua_helper.add_callback(lua, "getStoragePath", MobileAPI.getStoragePath);

		Lua_helper.add_callback(lua, "addVirtualPad", function(?dpad:Bool = true, ?actions:Dynamic = null, ?dispatchKeys:Bool = true) {
			return MobileAPI.addVirtualPad(dpad, toStringArray(actions), dispatchKeys);
		});
		Lua_helper.add_callback(lua, "removeVirtualPad", MobileAPI.removeVirtualPad);
		Lua_helper.add_callback(lua, "hasVirtualPad", MobileAPI.hasVirtualPad);
		Lua_helper.add_callback(lua, "setVirtualPadAlpha", function(alpha:Float) MobileAPI.setVirtualPadAlpha(alpha));
		Lua_helper.add_callback(lua, "setVirtualPadVisible", function(value:Bool) MobileAPI.setVirtualPadVisible(value));
		Lua_helper.add_callback(lua, "virtualPadPressed", function(key:String) return MobileAPI.virtualPadPressed(key));
		Lua_helper.add_callback(lua, "virtualPadJustPressed", function(key:String) return MobileAPI.virtualPadJustPressed(key));
		Lua_helper.add_callback(lua, "virtualPadJustReleased", function(key:String) return MobileAPI.virtualPadJustReleased(key));
	}

	static function findObject(name:String):FlxObject
	{
		if (name == null || name.length == 0) return null;
		var split:Array<String> = name.split('.');
		var obj:Dynamic = split.length > 1 ? LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length - 1]) : LuaUtils.getObjectDirectly(split[0]);
		return Std.isOfType(obj, FlxObject) ? obj : null;
	}

	static function cameraFrom(name:String):FlxCamera
	{
		if (name == null || name.length == 0) return null;
		return LuaUtils.cameraFromString(name);
	}

	static function toStringArray(value:Dynamic):Array<String>
	{
		if (value == null) return [];
		if (Std.isOfType(value, String))
			return [for (part in (value : String).split(' ')) if (part.length > 0) part];
		if (Std.isOfType(value, Array))
			return [for (item in (value : Array<Dynamic>)) Std.string(item)];
		var result:Array<String> = [];
		for (field in Reflect.fields(value))
			result.push(Std.string(Reflect.field(value, field)));
		return result;
	}
}
