@echo off
color 0a
cd /d "%~dp0.."
@echo on
echo Installing hmm...
haxelib --global install hmm
echo Installing dependencies from hmm.json into .haxelib...
echo This might take a few moments depending on your internet speed.
haxelib --global run hmm install
echo Building the hxcpp tools...
for /f "delims=" %%i in ('haxelib libpath hxcpp') do set HXCPP_PATH=%%i
pushd "%HXCPP_PATH%tools\hxcpp"
haxe compile.hxml
popd
echo Building lime for Windows...
haxelib run lime rebuild windows -64
echo Finished!
echo For Android run: haxelib run lime rebuild android -arm64
pause
