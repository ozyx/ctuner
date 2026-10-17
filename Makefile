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

.PHONY: build test test-release sanitize clean

build:
	$(SWIFT) build -c release

test:
	$(SWIFT) test $(TESTINGPLUGIN)

test-release:
	$(SWIFT) test -c release $(TESTINGPLUGIN)

# Address and undefined behaviour together, then thread on its own,
# because the thread sanitizer cannot share a run with the others
sanitize:
	$(SWIFT) test --sanitize=address --sanitize=undefined $(TESTINGPLUGIN)
	$(SWIFT) test --sanitize=thread $(TESTINGPLUGIN)

clean:
	$(SWIFT) package clean
