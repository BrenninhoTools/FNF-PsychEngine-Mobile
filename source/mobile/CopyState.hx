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

	var bytesDone:Float = 0;
	var bytesTotal:Float = 0;
	var speed:Float = 0;
	var lowSpace:Bool = false;

	#if android
	static inline final COPIER:String = 'org/psychengine/mobile/AssetCopier';
	var nativeRunning:Bool = false;
	var jniCache:Map<String, Dynamic> = new Map();

	function copier(name:String, signature:String):Dynamic
	{
		var key:String = name + signature;
		if (!jniCache.exists(key)) jniCache.set(key, JNI.createStaticMethod(COPIER, name, signature));
		return jniCache.get(key)();
	}
	#end

	var bar:FlxSprite;
	var status:FlxText;
	var detail:FlxText;

	public static function needsCopy():Bool
	{
		try
		{
			if (!FileSystem.exists(MARKER) || File.getContent(MARKER) != StorageUtil.getInstallStamp()) return true;
			return missingFiles(1).length > 0;
		}
		catch (e:Dynamic)
		{
			return true;
		}
	}

	static function shouldExtract(id:String):Bool
	{
		if (id.startsWith('manifest/') || id.startsWith('__')) return false;
		if (LimeAssets.exists(id, lime.utils.AssetType.FONT)) return false;
		return !unextractable().contains(id);
	}

	static function hasData(id:String):Bool
	{
		try
		{
			return LimeAssets.getBytes(id) != null || LimeAssets.getText(id) != null;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	static inline final SKIP_FILE:String = '.psych_unextractable';
	static var skipList:Array<String> = null;

	static function unextractable():Array<String>
	{
		if (skipList != null) return skipList;
		skipList = [];
		try
		{
			if (FileSystem.exists(SKIP_FILE))
				skipList = [for (line in File.getContent(SKIP_FILE).split('\n')) if (line.length > 0) line];
		}
		catch (e:Dynamic) {}
		return skipList;
	}

	public static function missingFiles(limit:Int = -1):Array<String>
	{
		var missing:Array<String> = [];
		for (id in LimeAssets.list())
		{
			if (!shouldExtract(id)) continue;
			if (!FileSystem.exists(id))
			{
				missing.push(id);
				if (limit > 0 && missing.length >= limit) break;
			}
		}
		return missing;
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
		stage = 'Reading the APK';
		JNI.createStaticMethod(COPIER, 'start', '(Ljava/lang/String;)V')(StorageUtil.getGameDir());
		nativeRunning = true;
		#else
		Thread.create(function() {
			StorageUtil.cleanTemp(StorageUtil.getGameDir() + 'assets');
			lowSpace = !StorageUtil.hasSpaceFor(64 * 1024 * 1024);
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
		var missing:Array<String> = missingFiles();

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
			if (!ok && !hasData(id))
			{
				ok = true;
				unextractable().push(id);
			}
			setProgress(id, ok);
		}

		try
		{
			if (unextractable().length > 0) File.saveContent(SKIP_FILE, unextractable().join('\n'));
		}
		catch (e:Dynamic) {}
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
			var nativeTotal:Int = copier('getTotal', '()I');
			var nativeDone:Int = copier('getDone', '()I');
			var nativeFailed:Int = copier('getFailed', '()I');
			var current:String = copier('getCurrent', '()Ljava/lang/String;');
			var nativeStage:String = copier('getStage', '()Ljava/lang/String;');
			mutex.acquire();
			total = nativeTotal;
			copied = nativeDone;
			failed = nativeFailed;
			currentFile = current == null ? '' : current;
			if (nativeStage != null && nativeStage.length > 0) stage = nativeStage;
			bytesDone = copier('getBytesDone', '()D');
			bytesTotal = copier('getBytesNeeded', '()D');
			speed = copier('getSpeed', '()D');
			lowSpace = copier('isLowSpace', '()Z') == true;
			mutex.release();

			if (copier('isFinished', '()Z') == true)
			{
				nativeRunning = false;
				var list:String = copier('getFailures', '()Ljava/lang/String;');
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
		var info:String = '$label: $done / $all';
		if (bytesTotal > 0) info += ' (' + StorageUtil.formatSize(bytesDone) + ' / ' + StorageUtil.formatSize(bytesTotal) + (speed > 0 ? ', ' + StorageUtil.formatSize(speed) + '/s' : '') + ')';
		if (errors > 0) info += ' - $errors failed';
		status.text = info;
		detail.text = lowSpace ? 'Not enough free space, some files may fail to copy. Free up space and reopen the game.\n' + file : file;
		detail.color = lowSpace ? 0xFFFF7777 : 0xFF777777;

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
