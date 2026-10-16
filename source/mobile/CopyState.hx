package mobile;

import flixel.FlxState;
import haxe.io.Bytes;
import haxe.io.Path;
import lime.utils.Assets as LimeAssets;
import states.TitleState;
import sys.thread.Mutex;
import sys.thread.Thread;
#if android
import lime.system.JNI;
#end

class CopyState extends FlxState
{
	static inline final MARKER:String = '.psych_assets';
	static final ROOTS:Array<String> = ['assets/', 'mods/'];
	static final ROOT_FILES:Array<String> = ['modsList.txt'];
	static final PRESERVE:Array<String> = ['mods/', 'modsList.txt'];

	var total:Int = 0;
	var copied:Int = 0;
	var failed:Int = 0;
	var currentFile:String = '';
	var stage:String = '';
	var finished:Bool = false;
	var leaving:Bool = false;
	var failures:Array<String> = [];
	var mutex:Mutex = new Mutex();

	#if android
	var nativeRunning:Bool = false;
	#end

	var bar:FlxSprite;
	var status:FlxText;
	var detail:FlxText;

	public static function needsCopy():Bool
	{
		try
		{
			return !FileSystem.exists(MARKER) || File.getContent(MARKER) != StorageUtil.getInstallStamp();
		}
		catch (e:Dynamic)
		{
			return true;
		}
	}

	override function create()
	{
		super.create();

		StorageUtil.ensureFolders();

		var title:FlxText = new FlxText(0, FlxG.height * 0.34, FlxG.width, 'Preparing game files...');
		title.setFormat(null, 32, FlxColor.WHITE, CENTER);
		add(title);

		var barBg:FlxSprite = new FlxSprite(FlxG.width * 0.15, FlxG.height * 0.5).makeGraphic(Std.int(FlxG.width * 0.7), 24, 0xFF333333);
		add(barBg);

		bar = new FlxSprite(barBg.x, barBg.y).makeGraphic(Std.int(barBg.width), 24, FlxColor.WHITE);
		bar.origin.set(0, 0);
		bar.scale.x = 0;
		add(bar);

		status = new FlxText(0, barBg.y + 40, FlxG.width, '');
		status.setFormat(null, 20, 0xFFAAAAAA, CENTER);
		add(status);

		detail = new FlxText(FlxG.width * 0.1, barBg.y + 72, FlxG.width * 0.8, '');
		detail.setFormat(null, 14, 0xFF777777, CENTER);
		add(detail);

		#if android
		stage = 'Copying from the APK';
		JNI.createStaticMethod('org/psychengine/mobile/AssetCopier', 'start', '(Ljava/lang/String;)V')(StorageUtil.getGameDir());
		nativeRunning = true;
		#else
		Thread.create(function() {
			copyFromBundle();
			verifyFromManifest();
			mutex.acquire();
			finished = true;
			mutex.release();
		});
		#end
	}

	static function shouldPreserve(path:String):Bool
	{
		for (prefix in PRESERVE)
			if (path.startsWith(prefix)) return true;
		return false;
	}

	static function isGameFile(path:String):Bool
	{
		if (ROOT_FILES.contains(path)) return true;
		for (root in ROOTS)
			if (path.startsWith(root)) return true;
		return false;
	}

	function setProgress(file:String, ok:Bool)
	{
		mutex.acquire();
		copied++;
		currentFile = file;
		if (!ok)
		{
			failed++;
			failures.push(file);
		}
		mutex.release();
	}

	#if ios
	function bundleRoot():String
	{
		var app:String = Path.addTrailingSlash(lime.system.System.applicationDirectory);
		if (FileSystem.exists(app + 'assets/assets') || FileSystem.exists(app + 'assets/mods') || FileSystem.exists(app + 'assets/modsList.txt'))
			return app + 'assets/';
		return app;
	}

	function collect(root:String, relative:String, out:Array<String>)
	{
		var full:String = root + relative;
		if (!FileSystem.exists(full)) return;
		if (FileSystem.isDirectory(full))
		{
			for (entry in FileSystem.readDirectory(full))
				collect(root, relative.length > 0 ? relative + '/' + entry : entry, out);
		}
		else out.push(relative);
	}
	#end

	function copyFromBundle()
	{
		#if ios
		var root:String = bundleRoot();
		var files:Array<String> = [];
		for (dir in ['assets', 'mods']) collect(root, dir, files);
		for (file in ROOT_FILES) if (FileSystem.exists(root + file)) files.push(file);

		mutex.acquire();
		stage = 'Copying from the app';
		total = files.length;
		mutex.release();

		for (file in files)
		{
			var ok:Bool = true;
			try
			{
				if (!(shouldPreserve(file) && FileSystem.exists(file)))
					copyWithRetry(function() return File.getBytes(root + file), file);
			}
			catch (e:Dynamic)
			{
				ok = false;
			}
			setProgress(file, ok);
		}
		#end
	}

	function verifyFromManifest()
	{
		var missing:Array<String> = [];
		for (id in LimeAssets.list())
		{
			if (id.startsWith('assets/embed/') || !isGameFile(id)) continue;
			if (!FileSystem.exists(id)) missing.push(id);
		}

		mutex.acquire();
		stage = 'Checking files';
		total += missing.length;
		mutex.release();

		for (id in missing)
		{
			var ok:Bool = true;
			try
			{
				copyWithRetry(function() {
					var bytes:Bytes = LimeAssets.getBytes(id);
					if (bytes == null)
					{
						var text:String = LimeAssets.getText(id);
						if (text != null) bytes = Bytes.ofString(text);
					}
					return bytes;
				}, id);
			}
			catch (e:Dynamic)
			{
				ok = false;
			}
			setProgress(id, ok);
		}
	}

	static function copyWithRetry(read:Void->Bytes, target:String)
	{
		var error:Dynamic = null;
		for (attempt in 0...3)
		{
			try
			{
				var bytes:Bytes = read();
				if (bytes == null) throw 'Missing asset: $target';
				var dir:String = Path.directory(target);
				if (dir.length > 0 && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
				var temp:String = target + '.part';
				File.saveBytes(temp, bytes);
				if (FileSystem.stat(temp).size != bytes.length) throw 'Size mismatch: $target';
				if (FileSystem.exists(target)) FileSystem.deleteFile(target);
				FileSystem.rename(temp, target);
				return;
			}
			catch (e:Dynamic)
			{
				error = e;
			}
		}
		throw error;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		#if android
		if (nativeRunning)
		{
			var copier:String = 'org/psychengine/mobile/AssetCopier';
			var nativeTotal:Int = JNI.createStaticMethod(copier, 'getTotal', '()I')();
			var nativeDone:Int = JNI.createStaticMethod(copier, 'getDone', '()I')();
			var nativeFailed:Int = JNI.createStaticMethod(copier, 'getFailed', '()I')();
			var current:String = JNI.createStaticMethod(copier, 'getCurrent', '()Ljava/lang/String;')();
			mutex.acquire();
			total = nativeTotal;
			copied = nativeDone;
			failed = nativeFailed;
			currentFile = current == null ? '' : current;
			mutex.release();

			if (JNI.createStaticMethod(copier, 'isFinished', '()Z')() == true)
			{
				nativeRunning = false;
				var list:String = JNI.createStaticMethod(copier, 'getFailures', '()Ljava/lang/String;')();
				if (list != null)
					for (line in list.split('\n'))
						if (line.length > 0) failures.push(line);
				Thread.create(function() {
					verifyFromManifest();
					mutex.acquire();
					finished = true;
					mutex.release();
				});
			}
		}
		#end

		mutex.acquire();
		var done:Int = copied;
		var all:Int = total;
		var errors:Int = failed;
		var complete:Bool = finished;
		var file:String = currentFile;
		var label:String = stage;
		mutex.release();

		bar.scale.x = all > 0 ? Math.min(1, done / all) : 0;
		status.text = '$label: $done / $all' + (errors > 0 ? ' ($errors failed)' : '');
		detail.text = file;

		if (complete && !leaving)
		{
			leaving = true;
			try
			{
				if (failures.length > 0)
				{
					StorageUtil.ensureFolders();
					File.saveContent('crash/copy_failures.txt', failures.join('\n'));
				}
				File.saveContent(MARKER, StorageUtil.getInstallStamp());
			}
			catch (e:Dynamic) {}

			#if LUA_ALLOWED
			Mods.pushGlobalMods();
			#end
			Mods.loadTopMod();
			FlxG.switchState(new TitleState());
		}
	}
}
