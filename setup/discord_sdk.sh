#!/bin/sh
set -e

PLATFORM="$1"
ARCHIVE="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
DISCORD="$ROOT/project/discord"

if [ -z "$PLATFORM" ] || [ ! -f "$ARCHIVE" ]; then
	echo "usage: discord_sdk.sh <android|ios> <sdk.zip>"
	exit 1
fi

unzip -q -o "$ARCHIVE" -d "$WORK/sdk"
for INNER in $(find "$WORK/sdk" -name "*.zip"); do
	unzip -q -o "$INNER" -d "${INNER%.zip}"
done

rm -rf "$DISCORD/include"
mkdir -p "$DISCORD/include/discord_partner_sdk"

copy_headers() {
	HEADER=$(find "$1" -name "discordpp.h" | head -n 1)
	if [ -z "$HEADER" ]; then
		return 1
	fi
	HEADER_DIR=$(dirname "$HEADER")
	cp "$HEADER_DIR"/*.h "$DISCORD/include/"
	cp "$HEADER_DIR"/*.h "$DISCORD/include/discord_partner_sdk/"
	return 0
}

if [ "$PLATFORM" = "android" ]; then
	AAR=$(find "$WORK/sdk" -name "discord_partner_sdk*.aar" | head -n 1)
	if [ -z "$AAR" ]; then
		echo "discord_partner_sdk.aar not found in the Discord Social SDK archive"
		exit 1
	fi
	unzip -q -o "$AAR" -d "$WORK/aar"

	SO=$(find "$WORK/aar" -path "*arm64-v8a*" -name "libdiscord_partner_sdk.so" | head -n 1)
	if [ -z "$SO" ]; then
		echo "arm64-v8a libdiscord_partner_sdk.so not found inside the aar"
		exit 1
	fi

	MOBILE="$ROOT/project/android/psychmobile"
	mkdir -p "$DISCORD/android/arm64-v8a" "$MOBILE/src/main/jniLibs/arm64-v8a" "$MOBILE/libs"
	cp "$SO" "$DISCORD/android/arm64-v8a/libdiscord_partner_sdk.so"
	cp "$SO" "$MOBILE/src/main/jniLibs/arm64-v8a/libdiscord_partner_sdk.so"
	cp "$WORK/aar/classes.jar" "$MOBILE/libs/discord_partner_sdk.jar"
	for JAR in $(find "$WORK/aar/libs" -name "*.jar" 2>/dev/null); do
		cp "$JAR" "$MOBILE/libs/discord_partner_sdk_$(basename "$JAR")"
	done

	copy_headers "$WORK/aar" || copy_headers "$WORK/sdk"
elif [ "$PLATFORM" = "ios" ]; then
	FRAMEWORK=$(find "$WORK/sdk" -type d -name "discord_partner_sdk.xcframework" | head -n 1)
	if [ -z "$FRAMEWORK" ]; then
		echo "discord_partner_sdk.xcframework not found in the Discord Social SDK archive"
		exit 1
	fi
	rm -rf "$DISCORD/ios"
	mkdir -p "$DISCORD/ios"
	cp -R "$FRAMEWORK" "$DISCORD/ios/"

	copy_headers "$DISCORD/ios/discord_partner_sdk.xcframework" || copy_headers "$WORK/sdk"
else
	echo "unknown platform $PLATFORM"
	exit 1
fi

if [ ! -f "$DISCORD/include/discordpp.h" ]; then
	echo "discordpp.h not found in the Discord Social SDK archive"
	exit 1
fi

rm -rf "$WORK"
echo "Discord Social SDK ready for $PLATFORM"
