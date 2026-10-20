package mobile;

class WideScreen
{
	public static var offset(get, never):Float;

	static function get_offset():Float
		return Math.max(0, (FlxG.width - FlxG.initialWidth) / 2);

	public static function fit<T:FlxSprite>(sprite:T):T
	{
		if (sprite == null || sprite.width <= 0 || sprite.width >= FlxG.width) return sprite;

		var centerY:Float = sprite.y + sprite.height / 2;
		var factor:Float = FlxG.width / sprite.width;
		sprite.scale.set(sprite.scale.x * factor, sprite.scale.y * factor);
		sprite.updateHitbox();
		sprite.x = (FlxG.width - sprite.width) / 2;
		sprite.y = centerY - sprite.height / 2;
		return sprite;
	}
}
