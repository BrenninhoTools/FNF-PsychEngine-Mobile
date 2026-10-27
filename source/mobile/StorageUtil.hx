package mobile;

import haxe.io.Path;
#if android
import lime.system.JNI;
#end

#if ios
@:cppFileCode('
extern "C" double psych_ios_free_space(void);
extern "C" double psych_ios_total_space(void);
')
#end
class StorageUtil
{
	public static inline final DATA:String = 'Data';
	public static inline final MEDIA:String = 'Media';
	public static inline final EXTERNAL:String = 'External';
	public static inline final OBB:String = 'Obb';
	public static final TYPES:Array<String> = [DATA, MEDIA, OBB, EXTERNAL];

	public static final FOLDERS:Array<String> = ['mods', 'crash', 'exports', 'screenshots'];
	public static final USER_FOLDERS:Array<String> = ['mods', 'exports', 'screenshots'];
	public static final USER_FILES:Array<String> = ['modsList.txt'];

	static var cachedGameDir:String = null;
	static var cachedType:String = null;

	public static function clearCache()
	{
		cachedGameDir = null;
		cachedType = null;
	}

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
		cachedGameDir = Path.addTrailingSlash(lime.system.System.documentsDirectory);
		return cachedGameDir;
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

	public static function getFreeSpace(?path:String):Float
	{
		#if android
		var value:Dynamic = jni('getFreeSpaceFor', '(Ljava/lang/String;)D')(path == null ? getGameDir() : path);
		return value == null ? -1 : value;
		#elseif ios
		return untyped __cpp__('psych_ios_free_space()');
		#else
		return -1;
		#end
	}

	public static function getTotalSpace(?path:String):Float
	{
		#if android
		var value:Dynamic = jni('getTotalSpaceFor', '(Ljava/lang/String;)D')(path == null ? getGameDir() : path);
		return value == null ? -1 : value;
		#elseif ios
		return untyped __cpp__('psych_ios_total_space()');
		#else
		return -1;
		#end
	}

	public static function hasSpaceFor(bytes:Float, ?path:String):Bool
	{
		var free:Float = getFreeSpace(path);
		return free < 0 || free >= bytes;
	}

	public static function getFolderSize(path:String):Float
	{
		#if android
		var value:Dynamic = jni('getFolderSize', '(Ljava/lang/String;)D')(path);
		return value == null ? 0 : value;
		#else
		return folderSizeHaxe(path);
		#end
	}

	static function folderSizeHaxe(path:String):Float
	{
		try
		{
			if (!FileSystem.exists(path)) return 0;
			if (!FileSystem.isDirectory(path)) return FileSystem.stat(path).size;
			var size:Float = 0;
			for (entry in FileSystem.readDirectory(path))
				size += folderSizeHaxe(Path.join([path, entry]));
			return size;
		}
		catch (e:Dynamic)
		{
			return 0;
		}
	}

	public static function isWritable(?path:String):Bool
	{
		if (path == null) path = getGameDir();
		#if android
		return jni('isWritable', '(Ljava/lang/String;)Z')(path) == true;
		#else
		var probe:String = Path.addTrailingSlash(path) + '.psych_probe';
		try
		{
			if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
			File.saveContent(probe, '1');
			FileSystem.deleteFile(probe);
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#end
	}

	public static function cleanTemp(?path:String):Int
	{
		if (path == null) path = getGameDir();
		#if android
		var count:Dynamic = jni('cleanTemp', '(Ljava/lang/String;)I')(path);
		return count == null ? 0 : count;
		#else
		return cleanTempHaxe(path);
		#end
	}

	static function cleanTempHaxe(path:String):Int
	{
		var count:Int = 0;
		try
		{
			if (!FileSystem.exists(path) || !FileSystem.isDirectory(path)) return 0;
			for (entry in FileSystem.readDirectory(path))
			{
				var full:String = Path.join([path, entry]);
				if (FileSystem.isDirectory(full)) count += cleanTempHaxe(full);
				else if (entry.endsWith('.part') || entry == '.psych_probe')
				{
					FileSystem.deleteFile(full);
					count++;
				}
			}
		}
		catch (e:Dynamic) {}
		return count;
	}

	public static function deleteFolder(path:String):Int
	{
		#if android
		var count:Dynamic = jni('deleteFolder', '(Ljava/lang/String;)I')(path);
		return count == null ? 0 : count;
		#else
		return deleteFolderHaxe(path);
		#end
	}

	static function deleteFolderHaxe(path:String):Int
	{
		var count:Int = 0;
		try
		{
			if (!FileSystem.exists(path)) return 0;
			if (!FileSystem.isDirectory(path))
			{
				FileSystem.deleteFile(path);
				return 1;
			}
			for (entry in FileSystem.readDirectory(path))
				count += deleteFolderHaxe(Path.join([path, entry]));
			FileSystem.deleteDirectory(path);
		}
		catch (e:Dynamic) {}
		return count;
	}

	public static function moveFolder(from:String, to:String):Int
	{
		#if android
		var count:Dynamic = jni('moveFolder', '(Ljava/lang/String;Ljava/lang/String;)I')(from, to);
		return count == null ? 0 : count;
		#else
		try
		{
			if (!FileSystem.exists(to))
			{
				var dir:String = Path.directory(to);
				if (dir.length > 0 && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
				FileSystem.rename(from, to);
				return 1;
			}
		}
		catch (e:Dynamic) {}
		var count:Int = copyFolderHaxe(from, to, false);
		deleteFolderHaxe(from);
		return count;
		#end
	}

	public static function describeSpace(?path:String):String
	{
		var free:Float = getFreeSpace(path);
		if (free < 0) return '';
		var all:Float = getTotalSpace(path);
		return formatSize(free) + ' free' + (all > 0 ? ' of ' + formatSize(all) : '');
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
			if (FileSystem.exists(to) && !overwrite && FileSystem.stat(to).size == FileSystem.stat(from).size) return 0;
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

	public static function migrate(fromDir:String, toDir:String, move:Bool = false):Int
	{
		if (fromDir == null || toDir == null) return 0;
		fromDir = Path.addTrailingSlash(fromDir);
		toDir = Path.addTrailingSlash(toDir);
		if (fromDir == toDir) return 0;
		if (!hasSpaceFor(getUserDataSize(fromDir), toDir)) move = false;

		var count:Int = 0;
		for (folder in USER_FOLDERS)
		{
			try
			{
				count += move ? moveFolder(fromDir + folder, toDir + folder) : copyFolder(fromDir + folder, toDir + folder, false);
			}
			catch (e:Dynamic) {}
		}
		for (file in USER_FILES)
		{
			try
			{
				if (FileSystem.exists(fromDir + file)) File.copy(fromDir + file, toDir + file);
			}
			catch (e:Dynamic) {}
		}
		return count;
	}

	public static function getUserDataSize(?root:String):Float
	{
		if (root == null) root = getGameDir();
		root = Path.addTrailingSlash(root);
		var size:Float = 0;
		for (folder in USER_FOLDERS) size += getFolderSize(root + folder);
		return size;
	}

	public static function applyGameDir()
	{
		clearCache();
		var dir:String = getGameDir();
		#if android
		if (getStorageType() != DATA && !isWritable(dir))
		{
			setStorageType(DATA);
			dir = getGameDir();
		}
		#end
		ensureFolders(dir);
		Sys.setCwd(dir);
		#if mobile
		Paths.resetModsRoot();
		#end
	}
}
