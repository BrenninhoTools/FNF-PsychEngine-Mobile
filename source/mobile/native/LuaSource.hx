package mobile.native;

@:keep
@:build(mobile.native.NativeBuild.addFiles('project/lua51/src', 'c', 'psych_lua51'))
class LuaSource
{
	public static function init() {}
}
