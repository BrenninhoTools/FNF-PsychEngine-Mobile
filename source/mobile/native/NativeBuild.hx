package mobile.native;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
#end

class NativeBuild
{
	#if macro
	public static function addFiles(folder:String, extension:String, group:String):Array<Field>
	{
		var root:String = projectRoot(Context.getPosInfos(Context.currentPos()).file);
		var dir:String = Path.normalize(root + '/' + folder);
		var files:String = '';
		for (file in FileSystem.readDirectory(dir))
			if (StringTools.endsWith(file, '.' + extension))
				files += '<file name="$dir/$file" />';

		var xml:String = '<files id="$group">$files</files><target id="haxe"><files id="$group" /></target>';
		Context.getLocalClass().get().meta.add(':buildXml', [macro $v{xml}], Context.currentPos());
		return Context.getBuildFields();
	}

	static function projectRoot(sourceFile:String):String
	{
		var dir:String = Path.normalize(FileSystem.absolutePath(Path.directory(sourceFile)));
		while (dir.length > 1)
		{
			if (FileSystem.exists(dir + '/project.hxp') || FileSystem.exists(dir + '/Project.xml')) return dir;
			var parent:String = Path.directory(dir);
			if (parent == dir || parent.length == 0) break;
			dir = parent;
		}
		return Path.normalize(FileSystem.absolutePath('.'));
	}
	#end
}
