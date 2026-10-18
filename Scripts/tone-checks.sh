#!/bin/bash
#
#  tone-checks.sh
#  Tuner
#
#  Runs tuner-run over known tones and checks the exit code of each.
#  It is a table: a name, the exit code that row must give, and the
#  arguments. A row that gives another code stops the script, which
#  fails the build. Every tone is at 110 Hz or above, where the
#  measured accuracy is within 0.5 cents at every tested rate.
#
#  usage: Scripts/tone-checks.sh TUNER-RUN
#
#  Exit codes of tuner-run: 0 pass, 1 fail, 2 usage, source or nothing
#  to judge.

set -euo pipefail

if [ $# -ne 1 ]
then
    echo "usage: $0 TUNER-RUN" >&2
    exit 2
fi

RUN=$1

# E4 in Kirnberger III with key C, in Hz, worked out from the published
# ratios and not from the app's table, so that the check can disagree
# with the table. In Kirnberger III (Kirnberger, Die Kunst des reinen
# Satzes, 1771 to 1779) the fifths C-G, G-D, D-A and A-E are each
# narrowed by a quarter of the syntonic comma, which makes the major
# third C-E pure, 5/4. A is three such fifths above C, so
#   E4 = 440 * (5/4) / ((27/16) * (80/81)^(3/4)) = 328.9767 Hz
# about 3.4 cents under the equal-tempered E4, 329.6276 Hz.
E4_KIRNBERGER_III=328.97673186866854

failures=0

# check NAME EXPECTED-EXIT TUNER-RUN-ARGS...
check()
{
    local name=$1
    local expected=$2
    shift 2

    local code=0
    local verdict
    verdict=$("$RUN" "$@" --quiet 2>&1) || code=$?

    if [ "$code" -eq "$expected" ]
    then
        printf 'ok   %-34s exit %s: %s\n' "$name" "$code" "$verdict"
    else
        printf 'FAIL %-34s exit %s, wanted %s: %s\n' \
               "$name" "$code" "$expected" "$verdict"
        failures=$((failures + 1))
    fi
}

# AE1: a tone 7 cents sharp reads 7 cents sharp
check "A4+7 against A4+7" 0 tone:A4+7 --target A4+7

# AE2: the same tone is not A4 at 0 cents
check "A4+7 against A4" 1 tone:A4+7 --target A4

# AE7: Kirnberger III's E4 is right in Kirnberger III and 3.4 cents
# flat in equal temperament
check "Kirnberger III E4 in Kirnberger III" 0 \
      "tone:$E4_KIRNBERGER_III" --temperament 1 --key 0 --target E4
check "Kirnberger III E4 in equal" 1 \
      "tone:$E4_KIRNBERGER_III" --target E4

# A rate other than the default
check "E4+5 at 96 kHz" 0 tone:E4+5,rate=96000 --target E4+5

if [ "$failures" -ne 0 ]
then
    echo "tone-checks: $failures failed" >&2
    exit 1
fi

echo "tone-checks: all passed"
