@echo off
color 0a
cd ..
@echo on
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
haxelib install lime 8.3.2
haxelib install openfl 9.5.2
haxelib install flixel 6.2.0
haxelib install flixel-addons 4.0.1
haxelib install flixel-tools 1.5.1
haxelib install hscript-iris 1.1.3
haxelib install tjson 1.4.0
haxelib install hxdiscord_rpc 1.3.0
haxelib install hxvlc 2.3.1 --skip-dependencies
haxelib set lime 8.3.2
haxelib set openfl 9.5.2
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 0188d47c982913eb10fad7bd75f062ddfc680f4b
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit daf0664aee99aa8b8d6bdd1eda993a1c3a399067
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis 4a77a1ffcc84bef9df45988f6794420a4e019670
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git cbf91e2180fd2e374924fe74844086aab7891666
haxelib git extension-androidtools https://github.com/MAJigsaw77/extension-androidtools 4ef308412a7ae88a60862d1e97a4aa34765b1dcc
echo Finished!
pause
