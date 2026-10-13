package mobile;

#if (DISCORD_ALLOWED && mobile)
#if android
import lime.system.JNI;
#end

@:build(mobile.NativeBuild.addFiles('project/discord', 'cpp', 'psych_discord', ['project/discord/include', 'project/discord/include/discord_partner_sdk'], ['-std=c++17'], #if android ['project/discord/android/arm64-v8a/libdiscord_partner_sdk.so'] #else [] #end))
@:cppFileCode('
extern "C" void psych_discord_init(const char *appId, const char *savePath);
extern "C" void psych_discord_login(void);
extern "C" void psych_discord_logout(void);
extern "C" void psych_discord_update(const char *details, const char *state, const char *largeImage, const char *largeText, const char *smallImage, double start, double end);
extern "C" void psych_discord_clear(void);
extern "C" int psych_discord_status(void);
extern "C" void psych_discord_run_callbacks(void);
extern "C" void psych_discord_shutdown(void);
')
class DiscordMobile
{
	public static inline final OFFLINE:Int = 0;
	public static inline final CONNECTING:Int = 1;
	public static inline final READY:Int = 2;
	public static inline final ERROR:Int = 3;
	public static inline final NEEDS_LOGIN:Int = 4;

	public static var running(default, null):Bool = false;

	public static function initialize(appId:String):Bool
	{
		if (running) return true;

		#if android
		var prepare:Dynamic = JNI.createStaticMethod('org/psychengine/mobile/DiscordBridge', 'prepare', '()Z');
		if (prepare == null || !prepare()) return false;
		#end

		var tokenPath:String = haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory) + 'discord_token';
		untyped __cpp__('psych_discord_init({0}.utf8_str(), {1}.utf8_str())', appId, tokenPath);
		lime.app.Application.current.onUpdate.add(onUpdate);
		running = true;
		return true;
	}

	public static function login()
	{
		if (running) untyped __cpp__('psych_discord_login()');
	}

	public static function logout()
	{
		if (running) untyped __cpp__('psych_discord_logout()');
	}

	public static function update(details:String, state:String, largeImage:String, largeText:String, smallImage:String, start:Float, end:Float)
	{
		if (!running) return;
		var detailsText:String = safe(details);
		var stateText:String = safe(state);
		var largeImageText:String = safe(largeImage);
		var largeTextText:String = safe(largeText);
		var smallImageText:String = safe(smallImage);
		untyped __cpp__('psych_discord_update({0}.utf8_str(), {1}.utf8_str(), {2}.utf8_str(), {3}.utf8_str(), {4}.utf8_str(), {5}, {6})',
			detailsText, stateText, largeImageText, largeTextText, smallImageText, start, end);
	}

	public static function clear()
	{
		if (running) untyped __cpp__('psych_discord_clear()');
	}

	public static function status():Int
	{
		return running ? untyped __cpp__('psych_discord_status()') : OFFLINE;
	}

	public static function shutdown()
	{
		if (!running) return;
		running = false;
		lime.app.Application.current.onUpdate.remove(onUpdate);
		untyped __cpp__('psych_discord_shutdown()');
	}

	static function onUpdate(elapsed:Int)
	{
		untyped __cpp__('psych_discord_run_callbacks()');
	}

	static function safe(value:String):String
	{
		return value == null ? '' : value;
	}
}
#end
