package mobile;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
#end

class NativeBuild
{
	#if macro
	static function projectRoot():String
	{
		var sourceFile:String = Context.getPosInfos(Context.currentPos()).file;
		return Path.normalize(FileSystem.absolutePath(Path.directory(sourceFile) + '/../..'));
	}

	public static function addFiles(folder:String, extension:String, group:String, ?includes:Array<String>, ?flags:Array<String>, ?libs:Array<String>):Array<Field>
	{
		var root:String = projectRoot();
		var dir:String = Path.normalize(root + '/' + folder);
		var files:String = '';

		if (includes != null)
			for (include in includes)
				files += '<compilerflag value="-I${Path.normalize(root + '/' + include)}" />';
		if (flags != null)
			for (flag in flags)
				files += '<compilerflag value="$flag" />';

		for (file in FileSystem.readDirectory(dir))
			if (StringTools.endsWith(file, '.' + extension))
				files += '<file name="$dir/$file" />';

		var linked:String = '';
		if (libs != null)
			for (lib in libs)
				linked += '<lib name="${Path.normalize(root + '/' + lib)}" />';

		var xml:String = '<files id="$group">$files</files><target id="haxe"><files id="$group" />$linked</target>';
		Context.getLocalClass().get().meta.add(':buildXml', [macro $v{xml}], Context.currentPos());
		return Context.getBuildFields();
	}
	#end
}
