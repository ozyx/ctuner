#!/bin/sh
#
#  measure.sh
#  Tuner
#
#  The performance and energy recipes (R21, R22, R34, AE3) run against
#  a Tuner you have already launched. It never starts the app, because
#  the microphone grant and the device are yours.
#
#  usage: Scripts/measure.sh cpu | wakeups | allocs | main | latency
#
#    cpu       60 s of top, first sample discarded, mean %CPU. Run it in
#              silence with the inspector hidden for AE3 (under 5), then
#              again with the inspector shown and record that too.
#    wakeups   top again, with idle wake-ups per second from the IDLEW
#              column. Run it with the window hidden for R34: CPU at the
#              idle floor, under one wake-up a second.
#    allocs    heap events per second from malloc_history, twice, once
#              with the window idle and once while a note plays; the
#              two rates should match, the strobe adding none. The app
#              must be launched with MallocStackLoggingNoCompact=1:
#                MallocStackLoggingNoCompact=1 .build/Tuner.app/Contents/MacOS/Tuner
#    main      sample of 5 s; prints the main thread's frames that
#              belong to the analysis. There should be none.
#    latency   the signposts for 10 s, hop publish to readout update.
#              The limit is one hop (1024 samples) plus one frame.
#
#  PID overrides the process looked up by name.

set -eu

NAME=Tuner
SUBSYSTEM=org.billthefarmer.Tuner

PID=${PID:-$(pgrep -x "$NAME" | head -n 1 || true)}

need_pid()
{
    if [ -z "$PID" ]
    then
        echo "measure: $NAME is not running; launch it first" >&2
        exit 2
    fi
}

# top_columns: top over N samples S seconds apart, as "cpu idlew" rows
top_columns()
{
    top -l "$1" -s "$2" -pid "$PID" -stats pid,cpu,idlew |
        awk -v pid="$PID" '$1 == pid && NF == 3 { print $2, $3 }'
}

cpu()
{
    need_pid
    echo "measure: 60 s of top on pid $PID, first sample discarded"
    top_columns 21 3 | awk 'NR > 1 { sum += $1; n++ }
        END { if (n) printf "mean %%CPU over %d samples: %.2f\n", n, sum / n }'
}

wakeups()
{
    need_pid
    echo "measure: 30 s of top on pid $PID, first sample discarded"
    top_columns 11 3 | awk 'NR == 1 { last = $2; next }
        { cpu += $1; wake += ($2 - last); last = $2; n++ }
        END { if (n) printf "mean %%CPU %.2f, idle wake-ups %.2f per second\n",
                            cpu / n, wake / (n * 3) }'
}

allocs()
{
    need_pid

    # Events recorded so far; each count is a heap allocation or free
    count()
    {
        malloc_history "$PID" -allEvents 2> /dev/null | grep -c 'ALLOC\|FREE' || true
    }

    first=$(count)
    sleep 10
    second=$(count)
    echo "measure: $((second - first)) heap events in 10 s on pid $PID"
    echo "per second: $(( (second - first) / 10 ))"
}

main_thread()
{
    need_pid
    out=$(mktemp)
    trap 'rm -f "$out"' EXIT
    sample "$PID" 5 -file "$out" > /dev/null

    # The main thread's block runs to the next thread header
    awk '/^    Thread_/ { show = ($0 ~ /main-thread/) } show' "$out" |
        grep -E 'TunerEngine|TunerCore|vDSP|ProcessBlock|analysis' ||
        echo "measure: no analysis function on the main thread"
}

latency()
{
    echo "measure: signposts from $SUBSYSTEM for 10 s"
    log stream --signpost --style ndjson --timeout 10s \
        --predicate "subsystem == \"$SUBSYSTEM\"" 2> /dev/null |
        python3 -I -c '
import json, sys
from datetime import datetime

hop = {}
gaps = []
for line in sys.stdin:
    try:
        event = json.loads(line)
        message = event["eventMessage"]
        when = datetime.strptime(event["timestamp"], "%Y-%m-%d %H:%M:%S.%f%z")
    except (ValueError, KeyError):
        continue
    kind, _, tick = message.partition(" ")
    if kind == "hop":
        hop[tick] = when
    elif kind == "readout" and tick in hop:
        gaps.append((when - hop.pop(tick)).total_seconds() * 1000)

if not gaps:
    print("measure: no hop and readout pairs; is a note playing?")
else:
    gaps.sort()
    print("pairs %d, median %.1f ms, 95th %.1f ms, worst %.1f ms" %
          (len(gaps), gaps[len(gaps) // 2],
           gaps[int(len(gaps) * 0.95)], gaps[-1]))
    print("limit: one hop (21 to 23 ms) plus one frame (8 to 17 ms)")
'
}

if [ $# -ne 1 ]
then
    echo "usage: $0 cpu | wakeups | allocs | main | latency" >&2
    exit 2
fi

case $1 in
cpu) cpu ;;
wakeups) wakeups ;;
allocs) allocs ;;
main) main_thread ;;
latency) latency ;;
*)
    echo "usage: $0 cpu | wakeups | allocs | main | latency" >&2
    exit 2
    ;;
esac
