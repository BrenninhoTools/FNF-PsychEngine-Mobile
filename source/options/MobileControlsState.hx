package options;

import flixel.input.keyboard.FlxKey;
import mobile.Hitbox;
import mobile.VirtualPad;

class MobileControlsState extends MusicBeatState
{
	static inline final ROW_HEIGHT:Int = 46;

	var settings:Array<{name:String, description:String, get:Void->String, change:Int->Void}>;
	var rows:Array<FlxText> = [];
	var curSelected:Int = 0;

	var hitbox:Hitbox;
	var pad:VirtualPad;
	var panel:FlxSprite;
	var titleText:FlxText;
	var descText:FlxText;

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Mobile Controls Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF2B2140;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);
		mobile.WideScreen.fit(bg);

		hitbox = new Hitbox(true);
		add(hitbox);

		settings = [
			{
				name: 'Hitbox Style',
				description: 'How the hitbox lanes look when you touch them.',
				get: () -> ClientPrefs.data.hitboxStyle,
				change: (dir:Int) -> ClientPrefs.data.hitboxStyle = cycle(Hitbox.STYLES, ClientPrefs.data.hitboxStyle, dir)
			},
			{
				name: 'Hitbox Colors',
				description: 'Notes: uses your Note Colors. Classic: the default FNF colors.\nPastel: softer colors. White: one color for every lane.',
				get: () -> ClientPrefs.data.hitboxColors,
				change: (dir:Int) -> ClientPrefs.data.hitboxColors = cycle(Hitbox.COLOR_MODES, ClientPrefs.data.hitboxColors, dir)
			},
			{
				name: 'Hitbox Opacity',
				description: 'How visible the hitbox lanes are when you touch them.',
				get: () -> Math.round(ClientPrefs.data.hitboxOpacity * 100) + '%',
				change: (dir:Int) -> ClientPrefs.data.hitboxOpacity = FlxMath.bound(Math.round((ClientPrefs.data.hitboxOpacity + dir * 0.05) * 100) / 100, 0.1, 1)
			},
			{
				name: 'Invisible Hitbox',
				description: 'If on, the hitbox is hidden during gameplay. It still works while hidden.',
				get: () -> ClientPrefs.data.hitboxInvisible ? 'ON' : 'OFF',
				change: (dir:Int) -> ClientPrefs.data.hitboxInvisible = !ClientPrefs.data.hitboxInvisible
			}
		];

		var panelWidth:Int = 620;
		var panelHeight:Int = 110 + settings.length * ROW_HEIGHT;
		panel = new FlxSprite((FlxG.width - panelWidth) / 2, 40).makeGraphic(panelWidth, panelHeight, FlxColor.BLACK);
		panel.alpha = 0.6;
		add(panel);

		titleText = new FlxText(panel.x, panel.y + 14, panelWidth, Language.getPhrase('mobile_controls_title', 'MOBILE CONTROLS'), 36);
		titleText.setFormat(Paths.font('vcr.ttf'), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);

		for (i in 0...settings.length)
		{
			var row:FlxText = new FlxText(panel.x + 20, panel.y + 70 + i * ROW_HEIGHT, panelWidth - 40, '', 28);
			row.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			row.borderSize = 2;
			rows.push(row);
			add(row);
		}

		descText = new FlxText(panel.x, panel.y + panelHeight + 12, panelWidth, '', 20);
		descText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		descText.borderSize = 1.5;
		add(descText);

		var hint:FlxText = new FlxText(0, FlxG.height - 34, FlxG.width, Language.getPhrase('mobile_controls_hint', 'Touch the screen to test the hitbox'), 20);
		hint.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		hint.alpha = 0.7;
		add(hint);

		pad = new VirtualPad(true, [ENTER, ESCAPE]);
		pad.onKey = onPadKey;
		add(pad);

		mobile.TouchInput.blockGestures = true;
		updateRows();
		super.create();
	}

	static function cycle(list:Array<String>, current:String, dir:Int):String
	{
		var index:Int = list.indexOf(current);
		if (index < 0) index = 0;
		return list[FlxMath.wrap(index + dir, 0, list.length - 1)];
	}

	function onPadKey(key:FlxKey, down:Bool)
	{
		if (!down) return;
		switch (key)
		{
			case UP: changeSelection(-1);
			case DOWN: changeSelection(1);
			case LEFT: changeValue(-1);
			case RIGHT | ENTER: changeValue(1);
			case ESCAPE: exit();
			default:
		}
	}

	function changeSelection(dir:Int)
	{
		curSelected = FlxMath.wrap(curSelected + dir, 0, settings.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));
		updateRows();
	}

	function changeValue(dir:Int)
	{
		settings[curSelected].change(dir);
		FlxG.sound.play(Paths.sound('scrollMenu'));
		hitbox.refresh();
		updateRows();
	}

	function updateRows()
	{
		for (i in 0...rows.length)
		{
			var selected:Bool = i == curSelected;
			var text:String = settings[i].name + ': ' + settings[i].get();
			rows[i].text = selected ? '< ' + text + ' >' : text;
			rows[i].alpha = selected ? 1 : 0.6;
			rows[i].color = selected ? 0xFFFFE066 : FlxColor.WHITE;
		}
		descText.text = settings[curSelected].description;
	}

	var exiting:Bool = false;
	function exit()
	{
		if (exiting) return;
		exiting = true;
		ClientPrefs.saveSettings();
		FlxG.sound.play(Paths.sound('cancelMenu'));
		OptionsState.reopenMobileOptions = true;
		MusicBeatState.switchState(new OptionsState());
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (exiting) return;

		var tapped:Int = mobile.TouchInput.tappedRow(cast rows);
		if (tapped > -1 && mobile.TouchInput.tapX >= panel.x && mobile.TouchInput.tapX <= panel.x + panel.width)
		{
			if (tapped == curSelected)
				changeValue(mobile.TouchInput.tapX < rows[tapped].x + rows[tapped].width / 2 ? -1 : 1);
			else
			{
				curSelected = tapped;
				FlxG.sound.play(Paths.sound('scrollMenu'));
				updateRows();
			}
			mobile.TouchInput.consumeTap();
		}

		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);
		if (controls.UI_LEFT_P) changeValue(-1);
		if (controls.UI_RIGHT_P || controls.ACCEPT) changeValue(1);
		if (controls.BACK) exit();
	}

	override function destroy()
	{
		mobile.TouchInput.blockGestures = false;
		super.destroy();
	}
}
