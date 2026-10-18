#
#  Makefile
#  Tuner
#
#  Builds and tests the Swift package at the repo root. The stage 1
#  AppKit app is still bundled by swift/Makefile, and the Linux port
#  has its own Makefile in linux/.
#

SWIFT = swift

# The Command Line Tools find the Swift Testing macro plugin only about
# half the time, so name its directory explicitly there. An Xcode
# toolchain, such as CI's, finds it on its own and the path would name
# a different toolchain, so leave it out.
CLT = /Library/Developer/CommandLineTools
TESTINGPLUGIN = $(if $(filter $(CLT),$(shell xcode-select -p 2>/dev/null)),\
	-Xswiftc -plugin-path -Xswiftc $(CLT)/usr/lib/swift/host/plugins/testing)

FIXTURES = Tests/TunerCoreTests/Fixtures
BIN = .build/release

# The app is bundled from this executable product with these resource
# bundles, into .build/Tuner.app, which git ignores with the rest of
# .build
APPPRODUCT = TunerApp
APPBUNDLES =
APPDIR = .build

# The core compiled on its own with every warning an error, and the
# symbols it would need from Cocoa, the Objective-C runtime or a logger
CORE = Sources/TunerCore
COREBUILD = .build/core-check
CORESOURCES = $(wildcard $(CORE)/*.c)
COREOBJECTS = $(patsubst $(CORE)/%.c,$(COREBUILD)/%.o,$(CORESOURCES))
CORECFLAGS = -O2 -Wall -Wextra -Werror -I$(CORE)/include
FORBIDDEN = '_objc_|_OBJC_|_NS|_CF|_os_log|_syslog|_asl_|printf|_puts|_fputs|_putchar|_fwrite|_perror'

.PHONY: build app test test-release sanitize core-check core-leaks fixtures fixture-screen tone-checks clean

build:
	$(SWIFT) build -c release

app:
	$(SWIFT) build -c release --product $(APPPRODUCT)
	Scripts/package-app.sh $(BIN)/$(APPPRODUCT) $(APPDIR) $(APPBUNDLES)

test:
	$(SWIFT) test $(TESTINGPLUGIN)

test-release:
	$(SWIFT) test -c release $(TESTINGPLUGIN)

# Address and undefined behaviour together, then thread on its own,
# because the thread sanitizer cannot share a run with the others
sanitize:
	$(SWIFT) test --sanitize=address --sanitize=undefined $(TESTINGPLUGIN)
	$(SWIFT) test --sanitize=thread $(TESTINGPLUGIN)

# The core builds warning-free and links nothing from Cocoa, the
# Objective-C runtime or a logger
core-check: $(COREOBJECTS)
	@if nm -u $(COREOBJECTS) | grep -E $(FORBIDDEN); then \
		echo "core-check: the core needs a forbidden symbol"; exit 1; fi
	@echo "core-check: clean"

# The engine's lifecycle a hundred times under leaks; it exits non-zero
# when anything leaks
core-leaks: $(COREOBJECTS)
	clang -g -I$(CORE)/include Scripts/core-leaks.c $(COREOBJECTS) \
		-framework Accelerate -o $(COREBUILD)/core-leaks
	MallocStackLogging=1 leaks --atExit -- $(COREBUILD)/core-leaks

$(COREBUILD)/%.o: $(CORE)/%.c $(wildcard $(CORE)/*.h $(CORE)/include/*.h)
	@mkdir -p $(COREBUILD)
	clang $(CORECFLAGS) -c $< -o $@

# Write every golden fixture from the frozen reference engine; a second
# run must leave the fixture files unchanged
fixtures:
	$(SWIFT) build -c release --product GoldenGenerator
	$(SWIFT) build -c release --product GoldenReference
	Scripts/fixtures.sh $(BIN)/GoldenGenerator $(BIN)/GoldenReference $(FIXTURES)

# Run tuner-run over known tones, each with the exit code it must give
tone-checks:
	$(SWIFT) build -c release --product tuner-run
	Scripts/tone-checks.sh $(BIN)/tuner-run

# Rebuild the reference at other optimisation levels and under the
# sanitizers, and check that every fixture holds
fixture-screen:
	Scripts/fixture-screen.sh $(FIXTURES) .build/fixture-screen

clean:
	$(SWIFT) package clean
