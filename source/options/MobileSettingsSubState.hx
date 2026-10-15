package options;

class MobileSettingsSubState extends BaseOptionsMenu
{
	#if android
	var initialStorage:String;
	#end
	var initialScreenStyle:String;

	public function new()
	{
		initialScreenStyle = ClientPrefs.data.screenStyle;
		title = Language.getPhrase('mobile_menu', 'Mobile Options');
		rpcTitle = 'Mobile Options Menu';

		var option:Option = new Option('Hitbox Visible',
			'If unchecked, the hitbox lanes are hidden during gameplay.\nThey still work while hidden.',
			'hitboxVisible',
			BOOL);
		addOption(option);

		var option:Option = new Option('Pause Button Visible',
			'If unchecked, the pause button is hidden during gameplay.\nYou can still tap its corner to pause.',
			'pauseButtonVisible',
			BOOL);
		addOption(option);

		var option:Option = new Option('Chart Editor in Pause',
			'If checked, the pause menu shows a "Chart Editor" option\nright after "Restart Song".',
			'pauseChartEditor',
			BOOL);
		addOption(option);

		var option:Option = new Option('Screen Style:',
			'Original: the classic 16:9 screen with black bars on wide phones.\nFull: fills the whole screen without stretching, showing more of the game on the sides.',
			'screenStyle',
			STRING,
			['Original', 'Full']);
		addOption(option);
		option.onChange = mobile.ScreenStyle.apply;

		#if android
		ClientPrefs.data.storageType = mobile.StorageUtil.useExternal() ? 'External' : 'Data';
		initialStorage = ClientPrefs.data.storageType;
		var option:Option = new Option('Storage Type:',
			'Data: files stay in the app folder and are deleted when the app is uninstalled.\nExternal: files go to /storage/emulated/0/.PsychEngine and stay after uninstalling.',
			'storageType',
			STRING,
			['Data', 'External']);
		addOption(option);
		option.onChange = onChangeStorage;
		#end

		super();
	}

	#if android
	function onChangeStorage()
	{
		if (ClientPrefs.data.storageType == 'External' && !mobile.StorageUtil.hasAccess())
			mobile.StorageUtil.requestAccess();
	}

	function closeStorage():Bool
	{
		if (ClientPrefs.data.storageType == initialStorage) return false;

		var oldDir:String = mobile.StorageUtil.getGameDir();
		mobile.StorageUtil.setUseExternal(ClientPrefs.data.storageType == 'External');
		ClientPrefs.saveSettings();
		if (mobile.StorageUtil.getGameDir() == oldDir) return false;

		mobile.StorageUtil.applyGameDir();
		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();
		if (mobile.CopyState.needsCopy())
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.switchState(new mobile.CopyState());
			return true;
		}
		return false;
	}
	#end

	override function close()
	{
		super.close();
		#if android
		if (closeStorage()) return;
		#end
		if (ClientPrefs.data.screenStyle != initialScreenStyle)
		{
			ClientPrefs.saveSettings();
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			FlxG.resetState();
		}
	}
}
