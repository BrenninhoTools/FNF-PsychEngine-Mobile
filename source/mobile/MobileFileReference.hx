package mobile;

import haxe.io.Bytes;
import haxe.io.Path;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.net.FileFilter;
import openfl.net.FileReference;
#if android
import lime.system.JNI;
#end

class MobileFileReference extends FileReference
{
	static inline final IDLE:Int = 0;
	static inline final WAITING:Int = 1;
	static inline final DONE:Int = 2;
	static inline final CANCELLED:Int = 3;

	#if android
	static inline final CLASS:String = 'org/psychengine/mobile/FileDialogs';
	static var jniCache:Map<String, Dynamic> = new Map();

	static function jni(name:String, signature:String):Dynamic
	{
		var key:String = name + signature;
		if (!jniCache.exists(key))
			jniCache.set(key, JNI.createStaticMethod(CLASS, name, signature));
		return jniCache.get(key);
	}
	#end

	var opening:Bool = false;
	var polling:Bool = false;

	public function new()
	{
		super();
	}

	static function tempDirectory():String
	{
		var dir:String = Path.addTrailingSlash(lime.system.System.applicationStorageDirectory) + 'file_dialogs/';
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		return dir;
	}

	static function mimeFor(fileName:String):String
	{
		return switch (Path.extension(fileName == null ? '' : fileName).toLowerCase())
		{
			case 'json': 'application/json';
			case 'txt': 'text/plain';
			case 'xml': 'text/xml';
			case 'lua': 'text/x-lua';
			case 'png': 'image/png';
			case 'ogg': 'audio/ogg';
			default: 'application/octet-stream';
		}
	}

	override public function save(data:Dynamic, defaultFileName:String = null):Void
	{
		if (defaultFileName == null || defaultFileName.length == 0) defaultFileName = 'file';
		var bytes:Bytes = Std.isOfType(data, Bytes) ? cast data : Bytes.ofString(Std.string(data));

		#if android
		try
		{
			var tempPath:String = tempDirectory() + 'pending_save';
			File.saveBytes(tempPath, bytes);
			opening = false;
			jni('reset', '()V')();
			jni('save', '(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V')(tempPath, defaultFileName, mimeFor(defaultFileName));
			@:privateAccess this.name = defaultFileName;
			startPolling();
		}
		catch (e:Dynamic)
		{
			dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
		}
		#else
		try
		{
			var dir:String = Path.addTrailingSlash(lime.system.System.documentsDirectory) + 'saves/';
			if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			File.saveBytes(dir + defaultFileName, bytes);
			@:privateAccess this.name = defaultFileName;
			@:privateAccess this.__path = dir + defaultFileName;
			dispatchEvent(new Event(Event.COMPLETE));
		}
		catch (e:Dynamic)
		{
			dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
		}
		#end
	}

	override public function browse(typeFilter:Array<FileFilter> = null):Bool
	{
		#if android
		@:privateAccess this.__path = null;
		@:privateAccess this.__data = null;
		opening = true;
		jni('reset', '()V')();
		jni('open', '(Ljava/lang/String;Ljava/lang/String;)V')('*/*', tempDirectory());
		startPolling();
		return true;
		#else
		dispatchEvent(new Event(Event.CANCEL));
		return false;
		#end
	}

	function startPolling()
	{
		if (polling) return;
		polling = true;
		FlxG.signals.postUpdate.add(poll);
	}

	function stopPolling()
	{
		if (!polling) return;
		polling = false;
		FlxG.signals.postUpdate.remove(poll);
	}

	function poll()
	{
		#if android
		var status:Int = jni('getStatus', '()I')();
		if (status == WAITING || status == IDLE) return;

		stopPolling();
		if (status == DONE)
		{
			if (opening)
			{
				var path:String = jni('getResultPath', '()Ljava/lang/String;')();
				@:privateAccess this.__path = path;
				@:privateAccess this.name = Path.withoutDirectory(path);
				try
				{
					@:privateAccess this.__data = openfl.utils.ByteArray.fromBytes(File.getBytes(path));
				}
				catch (e:Dynamic) {}
			}
			dispatchEvent(new Event(Event.COMPLETE));
		}
		else if (status == CANCELLED)
			dispatchEvent(new Event(Event.CANCEL));
		else
			dispatchEvent(new IOErrorEvent(IOErrorEvent.IO_ERROR));
		jni('reset', '()V')();
		#end
	}
}
