package options;

class MobileSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
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

		super();
	}
}
