package mobile;

import flixel.FlxState;
import states.TitleState;

class PermissionState extends FlxState
{
	var grantButton:TouchButton;
	var appFolderButton:TouchButton;
	var waiting:Bool = false;
	var checkTimer:Float = 0;
	var leaving:Bool = false;

	override function create()
	{
		super.create();

		var text:FlxText = new FlxText(80, 150, FlxG.width - 160,
			'Psych Engine stores its files and mods in\n/storage/emulated/0/.PsychEngine\n\n'
			+ 'Allow "All files access" so you can add mods\nfrom any file manager.', 28);
		text.alignment = CENTER;
		add(text);

		grantButton = new TouchButton(FlxG.width / 2 - 330, 480, 'ALLOW ACCESS', 300, 70, 26);
		add(grantButton);

		appFolderButton = new TouchButton(FlxG.width / 2 + 30, 480, 'USE APP FOLDER', 300, 70, 26);
		add(appFolderButton);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (leaving) return;

		if (grantButton.justTapped)
		{
			waiting = true;
			StorageUtil.requestAccess();
		}
		else if (appFolderButton.justTapped)
		{
			StorageUtil.setUseAppFolder(true);
			finish();
			return;
		}

		if (waiting)
		{
			checkTimer += elapsed;
			if (checkTimer >= 0.5)
			{
				checkTimer = 0;
				if (StorageUtil.hasAccess()) finish();
			}
		}
	}

	function finish()
	{
		leaving = true;
		StorageUtil.applyGameDir();
		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();
		if (CopyState.needsCopy()) FlxG.switchState(new CopyState());
		else FlxG.switchState(new TitleState());
	}
}
