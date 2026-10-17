#!/bin/sh
#
#  package-app.sh
#  Tuner
#
#  Bundles a package executable as an app: the executable, the named
#  resource bundles from beside it, App/Info.plist, PkgInfo and an
#  icon built from App/Tuner.png. The bundle is signed ad hoc with no
#  entitlements and no hardened runtime.
#
#  usage: Scripts/package-app.sh EXECUTABLE OUTDIR [BUNDLE...]
#
#  BUNDLE names a resource bundle in the executable's directory. Only
#  the named ones are copied, because the release directory also holds
#  the test bundles.

set -eu

if [ $# -lt 2 ]
then
    echo "usage: $0 EXECUTABLE OUTDIR [BUNDLE...]" >&2
    exit 2
fi

EXE=$1
OUT=$2
shift 2

APP=$(dirname "$0")/../App
PLB=/usr/libexec/PlistBuddy

NAME=$($PLB -c 'print :CFBundleExecutable' "$APP/Info.plist")
ICON=$($PLB -c 'print :CFBundleIconFile' "$APP/Info.plist")

BUNDLE=$OUT/$NAME.app
CONTENTS=$BUNDLE/Contents
RESOURCES=$CONTENTS/Resources

rm -rf "$BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$RESOURCES"

cp "$APP/Info.plist" "$CONTENTS/"
printf 'APPL????' > "$CONTENTS/PkgInfo"
cp "$EXE" "$CONTENTS/MacOS/$NAME"

for name in "$@"
do
    cp -R "$(dirname "$EXE")/$name" "$RESOURCES/"
done

# The icon, in a scratch directory that goes when the script exits
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

SET=$TMP/$NAME.iconset
mkdir "$SET"

for size in 16 32 128 256 512
do
    sips -z $size $size "$APP/Tuner.png" \
         --out "$SET/icon_${size}x${size}.png" > /dev/null
    sips -z $((size * 2)) $((size * 2)) "$APP/Tuner.png" \
         --out "$SET/icon_${size}x${size}@2x.png" > /dev/null
done

iconutil -c icns -o "$RESOURCES/$ICON" "$SET"

# Ad hoc, replacing the linker's signature on the executable; no
# entitlements and no --options runtime. The identifier stays the
# executable's name, Tuner, as the linker signed today's app, because
# the microphone grant is tied to the signature; codesign would
# otherwise take the bundle identifier.
codesign --force --sign - --identifier "$NAME" "$BUNDLE"
codesign --verify --strict --verbose=2 "$BUNDLE"
