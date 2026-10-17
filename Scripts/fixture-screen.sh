#!/bin/bash
#
#  fixture-screen.sh
#  Tuner
#
#  The stability screen for the golden fixtures. Builds the frozen
#  reference three more ways (-O0, -O3, and contraction off) and runs
#  every committed fixture through each. A fixture whose found, note
#  or count changes in any build sits on a threshold and would flake,
#  so the screen fails and names it.
#
#  Then builds the reference under the address and undefined-behaviour
#  sanitizers with recovery on, runs every fixture, lists the distinct
#  reports, and fails if the sanitized output differs from the
#  committed expected file anywhere.
#
#  usage: Scripts/fixture-screen.sh FIXTURES-DIR WORK-DIR

set -euo pipefail

if [ $# -ne 2 ]
then
    echo "usage: $0 FIXTURES-DIR WORK-DIR" >&2
    exit 2
fi

FIX=$1
WORK=$2
SRC=Sources/GoldenReference/main.m
FRAMEWORKS="-framework Cocoa -framework AudioToolbox -framework CoreAudio \
    -framework Accelerate"

rm -rf "$WORK"
mkdir -p "$WORK"

# build NAME FLAGS...
build()
{
    local name=$1
    shift
    clang -fobjc-arc -mmacosx-version-min=26.0 "$@" -o "$WORK/$name" \
          "$SRC" $FRAMEWORKS
}

build ref-O0 -O0
build ref-O3 -O3
build ref-nocontract -O2 -ffp-contract=off
build ref-sanitized -O1 -g -fsanitize=address,undefined \
      -fsanitize-recover=address,undefined

failed=0

for header in "$FIX"/*.header
do
    name=$(basename "$header" .header)
    input="$FIX/$name.bin"
    expected="$FIX/$name.expected.txt"

    # found, note and count in every build
    for variant in ref-O0 ref-O3 ref-nocontract
    do
        "$WORK/$variant" "$header" "$input" > "$WORK/$name.$variant.txt"
        if ! cmp -s <(cut -d' ' -f1-4 "$expected") \
                    <(cut -d' ' -f1-4 "$WORK/$name.$variant.txt")
        then
            echo "UNSTABLE $name: found, note or count differs in $variant"
            failed=1
        fi
    done

    # The sanitized build must print exactly the committed output
    ASAN_OPTIONS=halt_on_error=0:detect_leaks=0 \
    UBSAN_OPTIONS=halt_on_error=0:print_stacktrace=0 \
        "$WORK/ref-sanitized" "$header" "$input" \
        > "$WORK/$name.sanitized.txt" 2> "$WORK/$name.sanitized.log" || true

    if ! cmp -s "$expected" "$WORK/$name.sanitized.txt"
    then
        echo "SANITIZED OUTPUT DIFFERS $name"
        failed=1
    fi
done

echo "Sanitizer reports by fixture (source line and message):"
for log in "$WORK"/*.sanitized.log
do
    if [ -s "$log" ]
    then
        echo "$(basename "$log" .sanitized.log):"
        grep -oE "Audio.m:[0-9]+:[0-9]+: runtime error: .*|ERROR: AddressSanitizer: [a-z-]+" \
             "$log" | sed -E 's/value -?[0-9.e+]+ is/value is/' | sort -u |
            sed 's/^/    /' || true
    fi
done

exit $failed
