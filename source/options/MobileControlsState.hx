package options;

import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSpriteUtil;
import mobile.Hitbox;
import mobile.VirtualPad;

typedef ControlSetting = {
	name:String,
	description:String,
	?section:String,
	?get:Void->String,
	?change:Int->Void,
	?action:Void->Void,
	?visible:Void->Bool,
	?repeat:Bool
}

class MobileControlsState extends MusicBeatState
{
	static inline final ROW_HEIGHT:Int = 42;
	static inline final MAX_ROWS:Int = 9;
	static inline final LIST_WIDTH:Int = 640;
	static inline final INFO_WIDTH:Int = 420;
	static final LANE_NAMES:Array<String> = ['Left', 'Down', 'Up', 'Right'];
	static final ACCENT:FlxColor = 0xFFFFC94A;

	var settings:Array<ControlSetting>;
	var entries:Array<ControlSetting> = [];
	var curSelected:Int = 0;
	var scroll:Int = 0;
	var editLane:Int = 0;

	var hitbox:Hitbox;
	var pad:VirtualPad;

	var listX:Float;
	var listY:Float;
	var listPanel:FlxSprite;
	var rowBars:Array<FlxSprite> = [];
	var rowNames:Array<FlxText> = [];
	var rowValues:Array<FlxText> = [];
	var rowEntries:Array<ControlSetting> = [];
	var scrollUp:FlxText;
	var scrollDown:FlxText;

	var infoPanel:FlxSprite;
	var infoTitle:FlxText;
	var descText:FlxText;
	var swatch:FlxSprite;
	var thumbnail:FlxSprite;
	var statusText:FlxText;
	var statusTime:Float = 0;

	var heldKey:FlxKey = NONE;
	var holdTime:Float = 0;
	var importing:Bool = false;

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Mobile Controls Menu", null);
		#end

		if (ClientPrefs.data.hitboxRGB == null || ClientPrefs.data.hitboxRGB.length < 4)
			ClientPrefs.data.hitboxRGB = ClientPrefs.defaultData.hitboxRGB.copy();
		Hitbox.reloadImage();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF221A36;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);
		mobile.WideScreen.fit(bg);

		hitbox = new Hitbox(true);
		add(hitbox);

		buildSettings();

		var offset:Float = mobile.WideScreen.offset;
		listX = 36 + offset;
		listY = 86;

		var title:FlxText = new FlxText(listX, 22, LIST_WIDTH, Language.getPhrase('mobile_controls_title', 'MOBILE CONTROLS'), 40);
		title.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		title.borderSize = 2.5;
		add(title);

		listPanel = roundedPanel(listX - 10, listY - 10, LIST_WIDTH + 20, MAX_ROWS * ROW_HEIGHT + 20);
		add(listPanel);

		for (i in 0...MAX_ROWS)
		{
			var y:Float = listY + i * ROW_HEIGHT;
			var bar:FlxSprite = new FlxSprite(listX, y + 2).makeGraphic(LIST_WIDTH, ROW_HEIGHT - 4, FlxColor.WHITE);
			bar.alpha = 0;
			rowBars.push(bar);
			add(bar);

			var name:FlxText = new FlxText(listX + 14, y + 7, LIST_WIDTH * 0.55, '', 24);
			name.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
			name.borderSize = 1.5;
			rowNames.push(name);
			add(name);

			var value:FlxText = new FlxText(listX + LIST_WIDTH * 0.5, y + 7, LIST_WIDTH * 0.5 - 14, '', 24);
			value.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
			value.borderSize = 1.5;
			rowValues.push(value);
			add(value);
		}

		scrollUp = arrowText(listY - 30);
		scrollUp.text = '^';
		scrollDown = arrowText(listY + MAX_ROWS * ROW_HEIGHT + 4);
		scrollDown.text = 'v';

		var infoX:Float = listX + LIST_WIDTH + 34;
		infoPanel = roundedPanel(infoX, listY - 10, INFO_WIDTH, 300);
		add(infoPanel);

		infoTitle = new FlxText(infoX + 16, listY + 4, INFO_WIDTH - 32, '', 26);
		infoTitle.setFormat(Paths.font('vcr.ttf'), 26, ACCENT, LEFT, OUTLINE, FlxColor.BLACK);
		infoTitle.borderSize = 1.5;
		add(infoTitle);

		descText = new FlxText(infoX + 16, listY + 42, INFO_WIDTH - 32, '', 18);
		descText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		descText.borderSize = 1.2;
		add(descText);

		swatch = new FlxSprite(infoX + 16, listY + 196).makeGraphic(72, 72, FlxColor.WHITE);
		add(swatch);

		thumbnail = new FlxSprite(infoX + INFO_WIDTH - 16 - 120, listY + 168);
		thumbnail.antialiasing = ClientPrefs.data.antialiasing;
		add(thumbnail);

		statusText = new FlxText(infoX, listY + 300, INFO_WIDTH, '', 18);
		statusText.setFormat(Paths.font('vcr.ttf'), 18, ACCENT, CENTER, OUTLINE, FlxColor.BLACK);
		statusText.borderSize = 1.2;
		add(statusText);

		var hint:FlxText = new FlxText(0, FlxG.height - 30, FlxG.width, Language.getPhrase('mobile_controls_hint', 'Touch the empty space to test the hitbox'), 18);
		hint.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		hint.alpha = 0.6;
		add(hint);

		pad = new VirtualPad(true, [ENTER, ESCAPE]);
		pad.onKey = onPadKey;
		add(pad);

		mobile.TouchInput.blockGestures = true;
		updateThumbnail();
		updateRows();
		super.create();
	}

	function buildSettings()
	{
		var rgbMode:Void->Bool = () -> ClientPrefs.data.hitboxColors == 'RGB';
		var imageMode:Void->Bool = () -> Hitbox.hasImage();

		settings = [
			{section: 'HITBOX', name: '', description: ''},
			{
				name: 'Hitbox Mode',
				description: 'Four Lanes: the screen is split into four lanes.\nArrows: tap the arrows at the bottom of the screen.',
				get: () -> ClientPrefs.data.hitboxMode,
				change: (dir:Int) -> ClientPrefs.data.hitboxMode = cycle(['Four Lanes', 'Arrows'], ClientPrefs.data.hitboxMode, dir)
			},
			{
				name: 'Style',
				description: 'How the hitbox lanes look when you touch them.\nPick "Image" to use your own picture.',
				get: () -> ClientPrefs.data.hitboxStyle,
				change: (dir:Int) -> ClientPrefs.data.hitboxStyle = cycle(Hitbox.STYLES, ClientPrefs.data.hitboxStyle, dir)
			},
			{
				name: 'Opacity',
				description: 'How visible the hitbox lanes are when you touch them.\nHold the arrows to change it faster.',
				get: () -> Math.round(ClientPrefs.data.hitboxOpacity * 100) + '%',
				change: (dir:Int) -> ClientPrefs.data.hitboxOpacity = FlxMath.bound(Math.round((ClientPrefs.data.hitboxOpacity + dir * 0.05) * 100) / 100, 0.1, 1),
				repeat: true
			},
			{
				name: 'Invisible Hitbox',
				description: 'If on, the hitbox is hidden during gameplay.\nIt still works while hidden.',
				get: () -> ClientPrefs.data.hitboxInvisible ? 'ON' : 'OFF',
				change: (dir:Int) -> ClientPrefs.data.hitboxInvisible = !ClientPrefs.data.hitboxInvisible
			},
			{section: 'COLORS', name: '', description: ''},
			{
				name: 'Colors',
				description: 'Notes: your Note Colors. Classic: default FNF colors.\nPastel: softer colors. White: one color.\nRGB: pick your own color for each lane.',
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
				action: function()
				{
					ClientPrefs.data.hitboxRGB[editLane] = ClientPrefs.defaultData.hitboxRGB[editLane];
					showStatus(LANE_NAMES[editLane] + ' color reset');
				},
				visible: rgbMode
			},
			{section: 'IMAGE', name: '', description: ''},
			{
				name: 'Import Hitbox Image',
				description: 'Pick any image from your device (PNG, JPG, WEBP...)\nto replace the hitbox lanes. It switches the Style to "Image".',
				get: () -> Hitbox.hasImage() ? 'REPLACE' : 'IMPORT',
				action: importImage
			},
			{
				name: 'Image Fit',
				description: 'Stretch: fills each lane exactly.\nFit: keeps the shape, may leave empty space.\nFill: keeps the shape, may crop the image.',
				get: () -> ClientPrefs.data.hitboxImageFit,
				change: (dir:Int) -> ClientPrefs.data.hitboxImageFit = cycle(Hitbox.IMAGE_FITS, ClientPrefs.data.hitboxImageFit, dir),
				visible: imageMode
			},
			{
				name: 'Tint Image',
				description: 'If on, the image is tinted with the hitbox colors.\nIf off, it keeps its original colors.',
				get: () -> ClientPrefs.data.hitboxImageTint ? 'ON' : 'OFF',
				change: (dir:Int) -> ClientPrefs.data.hitboxImageTint = !ClientPrefs.data.hitboxImageTint,
				visible: imageMode
			},
			{
				name: 'Remove Hitbox Image',
				description: 'Deletes the imported image and goes back to the Gradient style.',
				get: () -> 'REMOVE',
				action: function()
				{
					Hitbox.removeImage();
					if (ClientPrefs.data.hitboxStyle == 'Image') ClientPrefs.data.hitboxStyle = 'Gradient';
					updateThumbnail();
					showStatus('Hitbox image removed');
				},
				visible: imageMode
			}
		];
	}

	function channelSetting(name:String, shift:Int, visible:Void->Bool):ControlSetting
	{
		return {
			name: name,
			description: 'The $name value of the selected lane color.\nHold the arrows to change it faster.',
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

	function roundedPanel(x:Float, y:Float, width:Int, height:Int):FlxSprite
	{
		var panel:FlxSprite = new FlxSprite(x, y).makeGraphic(width, height, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(panel, 0, 0, width, height, 24, 24, 0xB0000000, {thickness: 3, color: 0x60FFFFFF});
		return panel;
	}

	function arrowText(y:Float):FlxText
	{
		var text:FlxText = new FlxText(listX, y, LIST_WIDTH, '', 22);
		text.setFormat(Paths.font('vcr.ttf'), 22, ACCENT, CENTER, OUTLINE, FlxColor.BLACK);
		add(text);
		return text;
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

	static function selectable(entry:ControlSetting):Bool
	{
		return entry != null && entry.section == null;
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
			case ENTER: accept();
			case ESCAPE: exit();
			default:
		}
	}

	function changeSelection(dir:Int)
	{
		if (entries.length == 0) return;
		var index:Int = curSelected;
		for (_ in 0...entries.length)
		{
			index = FlxMath.wrap(index + dir, 0, entries.length - 1);
			if (selectable(entries[index])) break;
		}
		curSelected = index;
		FlxG.sound.play(Paths.sound('scrollMenu'));
		updateRows();
	}

	function accept()
	{
		var entry:ControlSetting = entries[curSelected];
		if (entry == null) return;
		if (entry.action != null)
		{
			FlxG.sound.play(Paths.sound('confirmMenu'));
			entry.action();
			hitbox.refresh();
			updateRows();
		}
		else changeValue(1);
	}

	function changeValue(dir:Int, quiet:Bool = false)
	{
		var entry:ControlSetting = entries[curSelected];
		if (entry == null || entry.change == null)
		{
			if (entry != null && entry.action != null && !quiet) accept();
			return;
		}
		entry.change(dir);
		if (!quiet) FlxG.sound.play(Paths.sound('scrollMenu'));
		hitbox.refresh();
		updateRows();
	}

	function importImage()
	{
		if (importing) return;
		importing = true;
		showStatus('Choose an image...', 30);
		mobile.NativeImport.pickHitboxImage(Hitbox.imagePath(), function(_)
		{
			importing = false;
			Hitbox.reloadImage();
			ClientPrefs.data.hitboxStyle = 'Image';
			hitbox.refresh();
			updateThumbnail();
			updateRows();
			FlxG.sound.play(Paths.sound('confirmMenu'));
			showStatus('Hitbox image imported!');
		}, function(message:String)
		{
			importing = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			showStatus(message);
		}, function()
		{
			importing = false;
			showStatus('');
		});
	}

	function updateThumbnail()
	{
		thumbnail.visible = false;
		if (!Hitbox.hasImage()) return;
		try
		{
			var bitmap:openfl.display.BitmapData = openfl.display.BitmapData.fromFile(Hitbox.imagePath());
			if (bitmap == null) return;
			thumbnail.loadGraphic(bitmap, false, 0, 0, true);
			var scale:Float = Math.min(120 / thumbnail.frameWidth, 120 / thumbnail.frameHeight);
			thumbnail.scale.set(scale, scale);
			thumbnail.updateHitbox();
			thumbnail.visible = true;
		}
		catch (e:Dynamic) {}
	}

	function showStatus(text:String, time:Float = 3)
	{
		statusText.text = text;
		statusText.alpha = 1;
		statusTime = time;
	}

	function updateRows()
	{
		var current:ControlSetting = entries[curSelected];
		entries = [for (setting in settings) if (setting.visible == null || setting.visible()) setting];
		if (current != null && entries.contains(current)) curSelected = entries.indexOf(current);
		curSelected = Std.int(FlxMath.bound(curSelected, 0, entries.length - 1));
		if (!selectable(entries[curSelected]))
		{
			for (i in curSelected...entries.length)
				if (selectable(entries[i]))
				{
					curSelected = i;
					break;
				}
		}

		if (curSelected < scroll + 1) scroll = curSelected - 1;
		if (curSelected >= scroll + MAX_ROWS) scroll = curSelected - MAX_ROWS + 1;
		scroll = Std.int(FlxMath.bound(scroll, 0, Math.max(0, entries.length - MAX_ROWS)));

		rowEntries = [];
		for (i in 0...MAX_ROWS)
		{
			var entry:ControlSetting = entries[scroll + i];
			rowEntries.push(entry);
			var name:FlxText = rowNames[i];
			var value:FlxText = rowValues[i];
			var bar:FlxSprite = rowBars[i];
			name.visible = value.visible = entry != null;
			bar.alpha = 0;
			if (entry == null) continue;

			if (entry.section != null)
			{
				name.text = entry.section;
				name.color = ACCENT;
				name.size = 20;
				value.text = '';
				continue;
			}

			var selected:Bool = scroll + i == curSelected;
			name.size = 24;
			name.text = entry.name;
			name.color = selected ? FlxColor.WHITE : 0xFFCCCCCC;
			var text:String = entry.get != null ? entry.get() : '';
			if (entry.action != null) value.text = '[ ' + text + ' ]';
			else value.text = selected ? '< ' + text + ' >' : text;
			value.color = selected ? ACCENT : 0xFFDDDDDD;
			bar.color = selected ? 0xFF6A4BC4 : FlxColor.WHITE;
			bar.alpha = selected ? 0.55 : 0.06;
		}

		scrollUp.visible = scroll > 0;
		scrollDown.visible = scroll + MAX_ROWS < entries.length;

		var entry:ControlSetting = entries[curSelected];
		infoTitle.text = entry != null ? entry.name : '';
		descText.text = entry != null ? entry.description : '';
		swatch.visible = ClientPrefs.data.hitboxColors == 'RGB';
		swatch.color = ClientPrefs.data.hitboxRGB[editLane];
	}

	var exiting:Bool = false;
	function exit()
	{
		if (exiting || importing) return;
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

		if (statusTime > 0)
		{
			statusTime -= elapsed;
			if (statusTime < 0.5) statusText.alpha = Math.max(0, statusTime / 0.5);
		}

		var entry:ControlSetting = entries[curSelected];
		if (heldKey != NONE && entry != null && entry.repeat == true)
		{
			holdTime += elapsed;
			if (holdTime > 0.4)
			{
				holdTime -= 0.06;
				changeValue(heldKey == LEFT ? -1 : 1, true);
			}
		}

		var tapped:Int = mobile.TouchInput.tappedRow(cast rowBars, 0);
		var tapX:Float = mobile.TouchInput.tapX;
		if (tapped > -1 && tapX >= listX && tapX <= listX + LIST_WIDTH)
		{
			var index:Int = scroll + tapped;
			if (index < entries.length && selectable(entries[index]))
			{
				if (index == curSelected)
				{
					if (entries[index].action != null) accept();
					else changeValue(tapX < listX + LIST_WIDTH * 0.75 ? -1 : 1);
				}
				else
				{
					curSelected = index;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					updateRows();
				}
			}
			mobile.TouchInput.consumeTap();
		}
		else if (mobile.TouchInput.tappedOn(scrollUp)) changeSelection(-1);
		else if (mobile.TouchInput.tappedOn(scrollDown)) changeSelection(1);

		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);
		if (controls.UI_LEFT_P) changeValue(-1);
		if (controls.UI_RIGHT_P) changeValue(1);
		if (controls.ACCEPT) accept();
		if (controls.BACK) exit();
	}

	override function destroy()
	{
		mobile.TouchInput.blockGestures = false;
		super.destroy();
	}
}
