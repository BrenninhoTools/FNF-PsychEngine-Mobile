package options;

import flixel.input.keyboard.FlxKey;
import mobile.Hitbox;
import mobile.VirtualPad;

typedef ControlSetting = {
	name:String,
	description:String,
	get:Void->String,
	change:Int->Void,
	?visible:Void->Bool,
	?repeat:Bool
}

class MobileControlsState extends MusicBeatState
{
	static inline final ROW_HEIGHT:Int = 40;
	static final LANE_NAMES:Array<String> = ['Left', 'Down', 'Up', 'Right'];

	var settings:Array<ControlSetting>;
	var visibleSettings:Array<ControlSetting> = [];
	var rows:Array<FlxText> = [];
	var curSelected:Int = 0;
	var editLane:Int = 0;

	var hitbox:Hitbox;
	var pad:VirtualPad;
	var panel:FlxSprite;
	var swatch:FlxSprite;
	var descText:FlxText;

	var heldKey:FlxKey = NONE;
	var holdTime:Float = 0;

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Mobile Controls Menu", null);
		#end

		if (ClientPrefs.data.hitboxRGB == null || ClientPrefs.data.hitboxRGB.length < 4)
			ClientPrefs.data.hitboxRGB = ClientPrefs.defaultData.hitboxRGB.copy();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF2B2140;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);
		mobile.WideScreen.fit(bg);

		hitbox = new Hitbox(true);
		add(hitbox);

		var rgbMode:Void->Bool = () -> ClientPrefs.data.hitboxColors == 'RGB';
		settings = [
			{
				name: 'Hitbox Style',
				description: 'How the hitbox lanes look when you touch them.',
				get: () -> ClientPrefs.data.hitboxStyle,
				change: (dir:Int) -> ClientPrefs.data.hitboxStyle = cycle(Hitbox.STYLES, ClientPrefs.data.hitboxStyle, dir)
			},
			{
				name: 'Hitbox Colors',
				description: 'Notes: your Note Colors. Classic: default FNF colors. Pastel: softer colors.\nWhite: one color for every lane. RGB: pick your own color for each lane.',
				get: () -> ClientPrefs.data.hitboxColors,
				change: (dir:Int) -> ClientPrefs.data.hitboxColors = cycle(Hitbox.COLOR_MODES, ClientPrefs.data.hitboxColors, dir)
			},
			{
				name: 'Lane',
				description: 'Which lane you are editing the color of.',
				get: () -> LANE_NAMES[editLane],
				change: (dir:Int) -> editLane = FlxMath.wrap(editLane + dir, 0, LANE_NAMES.length - 1),
				visible: rgbMode
			},
			channelSetting('Red', 16, rgbMode),
			channelSetting('Green', 8, rgbMode),
			channelSetting('Blue', 0, rgbMode),
			{
				name: 'Reset Lane Color',
				description: 'Puts this lane back to its default color.',
				get: () -> '#' + StringTools.hex(laneColorValue() & 0xFFFFFF, 6),
				change: (dir:Int) -> ClientPrefs.data.hitboxRGB[editLane] = ClientPrefs.defaultData.hitboxRGB[editLane],
				visible: rgbMode
			},
			{
				name: 'Hitbox Opacity',
				description: 'How visible the hitbox lanes are when you touch them.',
				get: () -> Math.round(ClientPrefs.data.hitboxOpacity * 100) + '%',
				change: (dir:Int) -> ClientPrefs.data.hitboxOpacity = FlxMath.bound(Math.round((ClientPrefs.data.hitboxOpacity + dir * 0.05) * 100) / 100, 0.1, 1),
				repeat: true
			},
			{
				name: 'Invisible Hitbox',
				description: 'If on, the hitbox is hidden during gameplay. It still works while hidden.',
				get: () -> ClientPrefs.data.hitboxInvisible ? 'ON' : 'OFF',
				change: (dir:Int) -> ClientPrefs.data.hitboxInvisible = !ClientPrefs.data.hitboxInvisible
			}
		];

		var panelWidth:Int = 640;
		panel = new FlxSprite((FlxG.width - panelWidth) / 2, 24).makeGraphic(panelWidth, 70 + settings.length * ROW_HEIGHT, FlxColor.BLACK);
		panel.alpha = 0.6;
		add(panel);

		var titleText:FlxText = new FlxText(panel.x, panel.y + 12, panelWidth, Language.getPhrase('mobile_controls_title', 'MOBILE CONTROLS'), 34);
		titleText.setFormat(Paths.font('vcr.ttf'), 34, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		add(titleText);

		for (i in 0...settings.length)
		{
			var row:FlxText = new FlxText(panel.x + 20, panel.y + 62 + i * ROW_HEIGHT, panelWidth - 40, '', 26);
			row.setFormat(Paths.font('vcr.ttf'), 26, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
			row.borderSize = 2;
			rows.push(row);
			add(row);
		}

		swatch = new FlxSprite(panel.x + panelWidth + 16, panel.y + 62).makeGraphic(64, 64, FlxColor.WHITE);
		add(swatch);

		descText = new FlxText(panel.x - 100, 0, panelWidth + 200, '', 20);
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

	function channelSetting(name:String, shift:Int, visible:Void->Bool):ControlSetting
	{
		return {
			name: name,
			description: 'The $name value of the selected lane color. Hold the arrows to change it faster.',
			get: () -> Std.string((laneColorValue() >> shift) & 0xFF),
			change: function(dir:Int)
			{
				var color:Int = laneColorValue();
				var value:Int = Std.int(FlxMath.bound(((color >> shift) & 0xFF) + dir * 5, 0, 255));
				color = (color & ~(0xFF << shift)) | (value << shift);
				ClientPrefs.data.hitboxRGB[editLane] = 0xFF000000 | (color & 0xFFFFFF);
			},
			visible: visible,
			repeat: true
		};
	}

	function laneColorValue():Int
	{
		var color:Int = ClientPrefs.data.hitboxRGB[editLane];
		return color;
	}

	static function cycle(list:Array<String>, current:String, dir:Int):String
	{
		var index:Int = list.indexOf(current);
		if (index < 0) index = 0;
		return list[FlxMath.wrap(index + dir, 0, list.length - 1)];
	}

	function onPadKey(key:FlxKey, down:Bool)
	{
		if (!down)
		{
			if (key == heldKey) heldKey = NONE;
			return;
		}
		switch (key)
		{
			case UP: changeSelection(-1);
			case DOWN: changeSelection(1);
			case LEFT | RIGHT:
				heldKey = key;
				holdTime = 0;
				changeValue(key == LEFT ? -1 : 1);
			case ENTER: changeValue(1);
			case ESCAPE: exit();
			default:
		}
	}

	function changeSelection(dir:Int)
	{
		curSelected = FlxMath.wrap(curSelected + dir, 0, visibleSettings.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));
		updateRows();
	}

	function changeValue(dir:Int, quiet:Bool = false)
	{
		var setting:ControlSetting = visibleSettings[curSelected];
		if (setting == null) return;
		setting.change(dir);
		if (!quiet) FlxG.sound.play(Paths.sound('scrollMenu'));
		hitbox.refresh();
		updateRows();
	}

	function updateRows()
	{
		var current:ControlSetting = visibleSettings[curSelected];
		visibleSettings = [for (setting in settings) if (setting.visible == null || setting.visible()) setting];
		if (current != null && visibleSettings.contains(current)) curSelected = visibleSettings.indexOf(current);
		curSelected = Std.int(FlxMath.bound(curSelected, 0, visibleSettings.length - 1));

		for (i in 0...rows.length)
		{
			var row:FlxText = rows[i];
			row.visible = i < visibleSettings.length;
			if (!row.visible) continue;
			var selected:Bool = i == curSelected;
			var text:String = visibleSettings[i].name + ': ' + visibleSettings[i].get();
			row.text = selected ? '< ' + text + ' >' : text;
			row.alpha = selected ? 1 : 0.6;
			row.color = selected ? 0xFFFFE066 : FlxColor.WHITE;
		}

		panel.setGraphicSize(Std.int(panel.width), 70 + visibleSettings.length * ROW_HEIGHT);
		panel.updateHitbox();
		descText.y = panel.y + panel.height + 10;
		descText.text = visibleSettings[curSelected].description;

		swatch.visible = ClientPrefs.data.hitboxColors == 'RGB';
		swatch.color = ClientPrefs.data.hitboxRGB[editLane];
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

		if (heldKey != NONE && visibleSettings[curSelected].repeat == true)
		{
			holdTime += elapsed;
			if (holdTime > 0.4)
			{
				holdTime -= 0.06;
				changeValue(heldKey == LEFT ? -1 : 1, true);
			}
		}

		var tapped:Int = mobile.TouchInput.tappedRow(cast rows);
		if (tapped > -1 && tapped < visibleSettings.length && mobile.TouchInput.tapX >= panel.x && mobile.TouchInput.tapX <= panel.x + panel.width)
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
