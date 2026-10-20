package mobile;

import haxe.io.Path;
#if android
import lime.system.JNI;
#end

class StorageUtil
{
	public static inline final DATA:String = 'Data';
	public static inline final MEDIA:String = 'Media';
	public static inline final EXTERNAL:String = 'External';
	public static inline final OBB:String = 'Obb';
	public static final TYPES:Array<String> = [DATA, MEDIA, OBB, EXTERNAL];

	static var cachedGameDir:String = null;
	static var cachedType:String = null;

	public static function clearCache()
	{
		cachedGameDir = null;
		cachedType = null;
	}
	public static final FOLDERS:Array<String> = ['mods', 'crash', 'exports', 'screenshots'];

	#if android
	static inline final CLASS:String = 'org/psychengine/mobile/Storage';
	static var jniCache:Map<String, Dynamic> = new Map();

	static function jni(name:String, signature:String):Dynamic
	{
		var key:String = name + signature;
		if (!jniCache.exists(key))
			jniCache.set(key, JNI.createStaticMethod(CLASS, name, signature));
		return jniCache.get(key);
	}
	#end

	public static function getGameDir():String
	{
		if (cachedGameDir != null) return cachedGameDir;
		#if android
		var path:String = jni('getGameDirPath', '()Ljava/lang/String;')();
		cachedGameDir = Path.addTrailingSlash(path != null && path.length > 0 ? path : lime.system.System.applicationStorageDirectory);
		return cachedGameDir;
		#elseif ios
		return Path.addTrailingSlash(lime.system.System.documentsDirectory);
		#else
		return Path.addTrailingSlash(Sys.getCwd());
		#end
	}

	public static function getDirFor(type:String):String
	{
		#if android
		var path:String = jni('getDirPathFor', '(Ljava/lang/String;)Ljava/lang/String;')(type);
		if (path != null && path.length > 0) return Path.addTrailingSlash(path);
		#end
		return getGameDir();
	}

	public static function getStorageType():String
	{
		if (cachedType != null) return cachedType;
		#if android
		var type:String = jni('getStorageType', '()Ljava/lang/String;')();
		cachedType = TYPES.contains(type) ? type : DATA;
		return cachedType;
		#else
		return DATA;
		#end
	}

	public static function setStorageType(type:String)
	{
		#if android
		if (!TYPES.contains(type)) type = DATA;
		jni('setStorageType', '(Ljava/lang/String;)V')(type);
		clearCache();
		#end
	}

	public static function useExternal():Bool
	{
		return getStorageType() == EXTERNAL;
	}

	public static function setUseExternal(value:Bool)
	{
		setStorageType(value ? EXTERNAL : DATA);
	}

	public static function isAppOwned():Bool
	{
		return getStorageType() != EXTERNAL;
	}

	public static function describe(?type:String):String
	{
		if (type == null) type = getStorageType();
		return switch (type)
		{
			case MEDIA: 'Android/media';
			case OBB: 'Android/obb';
			case EXTERNAL: '/storage/emulated/0/.PsychEngine';
			default: 'Android/data';
		}
	}

	public static function hasAccess():Bool
	{
		#if android
		return jni('hasAccess', '()Z')() == true;
		#else
		return true;
		#end
	}

	public static function requestAccess()
	{
		#if android
		jni('requestAccess', '()V')();
		#end
	}

	public static function getFreeSpace():Float
	{
		#if android
		var value:Dynamic = jni('getFreeSpace', '()D')();
		return value == null ? -1 : value;
		#else
		return -1;
		#end
	}

	public static function formatSize(bytes:Float):String
	{
		if (bytes < 0) return '?';
		var units:Array<String> = ['B', 'KB', 'MB', 'GB', 'TB'];
		var unit:Int = 0;
		while (bytes >= 1024 && unit < units.length - 1)
		{
			bytes /= 1024;
			unit++;
		}
		return (Math.round(bytes * 10) / 10) + ' ' + units[unit];
	}

	public static function getInstallStamp():String
	{
		#if android
		var stamp:String = jni('getInstallStamp', '()Ljava/lang/String;')();
		if (stamp != null && stamp.length > 0) return stamp;
		#elseif ios
		try
		{
			return lime.app.Application.current.meta.get('version') + '-' + FileSystem.stat(lime.system.System.applicationDirectory).mtime.getTime();
		}
		catch (e:Dynamic) {}
		#end
		return lime.app.Application.current.meta.get('version');
	}

	public static function ensureFolders(?root:String)
	{
		if (root == null) root = getGameDir();
		for (folder in FOLDERS)
		{
			try
			{
				var path:String = Path.addTrailingSlash(root) + folder;
				if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
			}
			catch (e:Dynamic) {}
		}
	}

	public static function copyFolder(from:String, to:String, overwrite:Bool = false):Int
	{
		#if android
		var count:Dynamic = jni('copyFolder', '(Ljava/lang/String;Ljava/lang/String;Z)I')(from, to, overwrite);
		return count == null ? 0 : count;
		#else
		return copyFolderHaxe(from, to, overwrite);
		#end
	}

	static function copyFolderHaxe(from:String, to:String, overwrite:Bool):Int
	{
		if (!FileSystem.exists(from)) return 0;
		if (!FileSystem.isDirectory(from))
		{
			if (FileSystem.exists(to) && !overwrite) return 0;
			var dir:String = Path.directory(to);
			if (dir.length > 0 && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			File.copy(from, to);
			return 1;
		}
		if (!FileSystem.exists(to)) FileSystem.createDirectory(to);
		var count:Int = 0;
		for (entry in FileSystem.readDirectory(from))
			count += copyFolderHaxe(Path.join([from, entry]), Path.join([to, entry]), overwrite);
		return count;
	}

	public static function migrate(fromDir:String, toDir:String):Int
	{
		if (fromDir == null || toDir == null || Path.addTrailingSlash(fromDir) == Path.addTrailingSlash(toDir)) return 0;
		var count:Int = 0;
		for (folder in ['mods', 'exports', 'screenshots'])
		{
			try
			{
				count += copyFolder(Path.addTrailingSlash(fromDir) + folder, Path.addTrailingSlash(toDir) + folder, false);
			}
			catch (e:Dynamic) {}
		}
		try
		{
			var list:String = Path.addTrailingSlash(fromDir) + 'modsList.txt';
			var target:String = Path.addTrailingSlash(toDir) + 'modsList.txt';
			if (FileSystem.exists(list)) File.copy(list, target);
		}
		catch (e:Dynamic) {}
		return count;
	}

	public static function applyGameDir()
	{
		clearCache();
		var dir:String = getGameDir();
		ensureFolders(dir);
		Sys.setCwd(dir);
		#if mobile
		Paths.resetModsRoot();
		#end
	}
}
