package mobile;

#if android
import lime.system.JNI;
#end

class VSliceImport
{
	static inline final WAITING:Int = 1;
	static inline final DONE:Int = 2;
	static inline final CANCELLED:Int = 3;

	#if android
	static inline final DIALOGS:String = 'org/psychengine/mobile/FileDialogs';
	static inline final IMPORT:String = 'org/psychengine/mobile/VSliceImport';

	static var onDone:String->String->Void;
	static var onFail:String->Void;
	static var polling:Bool = false;

	public static function pick(done:String->String->Void, fail:String->Void)
	{
		if (polling) return;
		onDone = done;
		onFail = fail;

		var dir:String = haxe.io.Path.addTrailingSlash(lime.system.System.applicationStorageDirectory) + 'file_dialogs/vslice/';
		try
		{
			if (FileSystem.exists(dir))
			{
				for (file in FileSystem.readDirectory(dir))
					if (!FileSystem.isDirectory(dir + file)) FileSystem.deleteFile(dir + file);
			}
			else FileSystem.createDirectory(dir);
		}
		catch (e:Dynamic) {}

		JNI.createStaticMethod(DIALOGS, 'reset', '()V')();
		JNI.createStaticMethod(DIALOGS, 'openVSlice', '(Ljava/lang/String;)V')(dir);
		polling = true;
		FlxG.signals.postUpdate.add(poll);
	}

	static function poll()
	{
		var status:Int = JNI.createStaticMethod(DIALOGS, 'getStatus', '()I')();
		if (status == WAITING || status == 0) return;

		polling = false;
		FlxG.signals.postUpdate.remove(poll);
		JNI.createStaticMethod(DIALOGS, 'reset', '()V')();

		var done = onDone;
		var fail = onFail;
		onDone = null;
		onFail = null;

		if (status == CANCELLED) return;
		if (status != DONE)
		{
			var message:String = JNI.createStaticMethod(IMPORT, 'getMessage', '()Ljava/lang/String;')();
			if (fail != null) fail(message != null && message.length > 0 ? message : 'Could not read the selected files.');
			return;
		}

		try
		{
			var chart:String = File.getContent(JNI.createStaticMethod(IMPORT, 'getChartPath', '()Ljava/lang/String;')());
			var metadata:String = File.getContent(JNI.createStaticMethod(IMPORT, 'getMetadataPath', '()Ljava/lang/String;')());
			if (done != null) done(chart, metadata);
		}
		catch (e:Dynamic)
		{
			if (fail != null) fail(Std.string(e));
		}
	}
	#end
}
