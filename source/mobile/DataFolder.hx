package mobile;

#if android
import lime.system.JNI;
#end

class DataFolder
{
	#if android
	static var openJNI:Dynamic = null;
	#end

	public static function open()
	{
		#if android
		if (openJNI == null)
			openJNI = JNI.createStaticMethod('org/psychengine/mobile/DataFolder', 'open', '()V');
		if (openJNI != null) openJNI();
		#elseif ios
		var path:String = haxe.io.Path.addTrailingSlash(lime.system.System.documentsDirectory);
		lime.system.System.openURL('shareddocuments://' + StringTools.urlEncode(path).replace('%2F', '/'));
		#end
	}
}
