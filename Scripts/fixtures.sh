#!/bin/bash
#
#  fixtures.sh
#  Tuner
#
#  Writes every golden fixture: the input from GoldenGenerator, the
#  header, and the expected per-hop output of the frozen engine from
#  GoldenReference. Running it again must leave git with no changes;
#  that is the reproducibility check.
#
#  usage: Scripts/fixtures.sh GENERATOR REFERENCE OUTDIR
#
#  The header format and the line format are in
#  Tests/TunerCoreTests/Fixtures/README.md.

set -euo pipefail

if [ $# -ne 3 ]
then
    echo "usage: $0 GENERATOR REFERENCE OUTDIR" >&2
    exit 2
fi

GEN=$1
REF=$2
OUT=$3

mkdir -p "$OUT"

# fixture NAME "CONFIG LINES" GENERATOR-ARGS...
#
# CONFIG LINES are header lines for the engine and the tests, one per
# line, overriding the defaults the reference and the tests share:
# rate 44100, reference 440, temper 8 (equal), key 0, filt 0, down 0,
# fund 0, note 0, notes fff, octaves 1ff, filt_toggle_hop -1,
# expect_hz none, expect_cents 0.2, same_binary_only 0.
fixture()
{
    local name=$1
    local config=$2
    shift 2

    local header="$OUT/$name.header"
    local input="$OUT/$name.bin"

    {
        echo "name $name"
        if [ -n "$config" ]
        then
            printf '%s\n' "$config"
        fi
        "$GEN" --out "$input" "$@"
    } > "$header"

    "$REF" "$header" "$input" > "$OUT/$name.expected.txt"
}

# Smoke and invariants
fixture silence ""
fixture noise "" --noise 0.5:12345

# Pure tones across the range
# The two lowest sit 10 and 20 bins above zero, where today's engine
# reads about 1 and 0.6 cents off, so their accuracy bound is wider
fixture tone-00027.5 "expect_hz 27.5
expect_cents 1.2" --tone 27.5:0.5:0
fixture tone-00055.0 "expect_hz 55
expect_cents 0.8" --tone 55:0.5:0

for hz in 110 220 440 880 1760 4000
do
    name=$(printf 'tone-%07.1f' "$hz")
    fixture "$name" "expect_hz $hz" --tone "$hz:0.5:0"
done

# Detuned from A4, and one on the 50 cent boundary that may flip
# between notes from build to build
fixture detune-p45 "expect_hz 451.58686491178656" \
        --tone 451.58686491178656:0.5:0
fixture detune-m45 "expect_hz 428.7104321287511" \
        --tone 428.7104321287511:0.5:0
fixture detune-p48 "expect_hz 452.3700837286693" \
        --tone 452.3700837286693:0.5:0
fixture detune-p50 "expect_hz 452.8929841231365
same_binary_only 1" \
        --tone 452.8929841231365:0.5:0

# Two tones closer than a bin, so the peak count changes hop to hop
fixture pair-440-442 "" --tone 440:0.3:0 --tone 442:0.3:1

# Harmonic-rich low notes with downsampling on; the harmonic product
# shifts low notes by up to about 2.6 cents today
for hz in 27.5 55 110
do
    name=$(printf 'down-harmonic-%05.1f' "$hz")
    fixture "$name" "down 1
expect_hz $hz
expect_cents 3" --harmonic "$hz:0.5:5"
done

# A pure sine with downsampling on is not found
fixture down-sine-0440 "down 1" --tone 440:0.5:0

# The input filter on, for a low and a high tone
fixture filt-0220 "filt 1
expect_hz 220" --tone 220:0.5:0
fixture filt-1760 "filt 1
expect_hz 1760" --tone 1760:0.5:0

# The fundamental filter with a harmonic-rich tone
fixture fund-harmonic-110 "fund 1" --harmonic 110:0.5:5

# The note filter: A only, and octave 4 only
fixture note-a-only "note 1
notes 200" --harmonic 110:0.5:5
fixture note-octave-4 "note 1
octaves 010" --harmonic 220:0.5:5

# A C5 with the note filter at A in octave 4: nothing passes (AE7)
fixture note-c5-filtered "note 1
notes 200
octaves 010" --tone 523.2511306011972:0.5:0

# A non-equal temperament in another key: Kirnberger III in G
fixture temper-kirnberger3-g "temper 1
key 7" --tone 440:0.5:0

# Another reference
fixture reference-415 "reference 415
expect_hz 415" --tone 415:0.5:0

# The input filter switched on half way through
fixture filt-toggle-32 "filt_toggle_hop 32" --tone 220:0.5:0

# No many-peak fixture: eight tones that fill the maxima list make the
# frozen engine write one element past it, and its output then changes
# with the build (see the README)
