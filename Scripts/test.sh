#!/bin/zsh
# Runs the test suite. With full Xcode installed, plain `swift test` works;
# with only the Command Line Tools, the Swift Testing framework lives in a
# non-default location and needs explicit search/runtime paths.
set -euo pipefail
cd "$(dirname "$0")/.."

# Default to a release build: the story soak tests composite millions of
# frames and are >100x slower unoptimized (33s vs. over an hour).
if [[ " $* " != *" -c "* && " $* " != *" --configuration "* ]]; then
    set -- -c release "$@"
fi

if xcode-select -p 2>/dev/null | grep -q "CommandLineTools"; then
    FWK=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
    LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
    exec swift test \
        -Xswiftc -F"$FWK" \
        -Xlinker -F"$FWK" \
        -Xlinker -rpath -Xlinker "$FWK" \
        -Xlinker -rpath -Xlinker "$LIB" \
        "$@"
else
    exec swift test "$@"
fi
