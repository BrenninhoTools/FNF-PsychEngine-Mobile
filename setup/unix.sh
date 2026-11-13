#!/bin/sh
cd "$(dirname "$0")/.."
echo Installing hmm...
haxelib --global install hmm
echo Installing dependencies from hmm.json into .haxelib...
echo This might take a few moments depending on your internet speed.
haxelib --global run hmm install
echo Building the hxcpp tools...
(cd "$(haxelib libpath hxcpp)/tools/hxcpp" && haxe compile.hxml)
echo Building lime for this computer...
case "$(uname -s)" in
	Darwin) haxelib run lime rebuild mac -64 ;;
	*) haxelib run lime rebuild linux -64 ;;
esac
echo Finished!
echo For Android run: haxelib run lime rebuild android -arm64
echo For iOS run: haxelib run lime rebuild ios
