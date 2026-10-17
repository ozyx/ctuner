#
#  Makefile
#  Tuner
#
#  Created by Bill Farmer on 10/10/2017.
#  Copyright © 2017 Bill Farmer. All rights reserved.
#

RM = rm
MD = mkdir
CP = cp
LN = ln
CC = gcc

HDIU = hdiutil
SWIFTC = swiftc
PLB = /usr/libexec/PlistBuddy
SIPS = sips
IBT = ibtool

AUDIO = Audio
AUDIOOBJ = $(AUDIO).o

APPNAME = Tuner

APPVERSION = $(shell $(PLB) -c 'print :CFBundleShortVersionString' Info.plist)

APPBUNDLE = $(APPNAME).app
APPBUNDLECONTENTS = $(APPBUNDLE)/Contents
APPBUNDLEMACOS = $(APPBUNDLECONTENTS)/MacOS
APPBUNDLERESOURCES = $(APPBUNDLECONTENTS)/Resources
APPBUNDLEBASE = $(APPBUNDLERESOURCES)/Base.lproj
APPBUNDLEICON = $(APPBUNDLECONTENTS)/Resources

APPDMG = $(APPNAME).dmg
APPVDMG = $(APPNAME)-$(APPVERSION).dmg

HEADER = Tuner-Bridging-Header.h
SWIFTH = Tuner-Swift.h

SOURCES = AppDelegate.swift ScopeView.swift SpectrumView.swift \
	StrobeView.swift DisplayView.swift MeterView.swift \
	StaffView.swift TunerView.swift main.swift

# Optimised, so the stage 1 baseline measures a fair build
SFLAGS = -O -target arm64-apple-macos14 -swift-version 5 -module-name Tuner \
	-import-objc-header $(HEADER) -emit-objc-header-path $(SWIFTH)

CFLAGS = -O2 -target arm64-apple-macos14

$(APPBUNDLE): $(APPNAME) $(APPNAME).icns Info.plist PkgInfo $(APPNAME).entitlements
	$(RM) -rf $(APPBUNDLE)
	$(MD) -p $(APPBUNDLEMACOS)
	$(MD) -p $(APPBUNDLERESOURCES)
	$(CP) Info.plist $(APPBUNDLECONTENTS)/
	$(CP) PkgInfo $(APPBUNDLECONTENTS)/
	$(CP) $(APPNAME).icns $(APPBUNDLERESOURCES)/
	$(CP) $(APPNAME).entitlements $(APPBUNDLERESOURCES)/
	$(CP) $(APPNAME) $(APPBUNDLEMACOS)/

$(APPNAME): $(SOURCES) $(AUDIOOBJ)
	$(SWIFTC) $(SOURCES) $(AUDIOOBJ) -o $(APPNAME) $(SFLAGS)

$(AUDIOOBJ):	$(AUDIO).m $(AUDIO).h Temperaments.h Makefile
	$(CC) -c $(CFLAGS) $(AUDIO).m -o $(AUDIOOBJ)

$(APPNAME).icns: $(APPNAME).png
	$(RM) -rf $(APPNAME).iconset
	$(MD) $(APPNAME).iconset
	$(SIPS) -z 16 16   $(APPNAME).png --out $(APPNAME).iconset/icon_16x16.png
	$(SIPS) -z 32 32   $(APPNAME).png --out $(APPNAME).iconset/icon_16x16@2x.png
	$(SIPS) -z 32 32   $(APPNAME).png --out $(APPNAME).iconset/icon_32x32.png
	$(SIPS) -z 64 64   $(APPNAME).png --out $(APPNAME).iconset/icon_32x32@2x.png
	$(SIPS) -z 128 128 $(APPNAME).png --out $(APPNAME).iconset/icon_128x128.png
	$(SIPS) -z 256 256 $(APPNAME).png --out $(APPNAME).iconset/icon_128x128@2x.png
	$(SIPS) -z 256 256 $(APPNAME).png --out $(APPNAME).iconset/icon_256x256.png
	$(SIPS) -z 512 512 $(APPNAME).png --out $(APPNAME).iconset/icon_256x256@2x.png
	$(SIPS) -z 512 512 $(APPNAME).png --out $(APPNAME).iconset/icon_512x512.png
	$(SIPS) -z 1024 1024 $(APPNAME).png --out $(APPNAME).iconset/icon_512x512@2x.png
	iconutil -c icns -o $(APPNAME).icns $(APPNAME).iconset
	$(RM) -r $(APPNAME).iconset

clean:
	$(RM) -rf $(APPBUNDLE)
	$(RM) -f $(APPNAME).icns $(APPNAME) $(AUDIOOBJ) $(APPDMG) $(APPVDMG)

$(APPVDMG): $(APPBUNDLE)
	$(HDIU) create -size 16m -fs HFS+ -volname $(APPNAME) -ov $(APPNAME) -quiet
	$(HDIU) attach $(APPDMG) -quiet
	$(CP) -r $(APPBUNDLE) /Volumes/$(APPNAME)
	$(LN) -s /Applications /Volumes/$(APPNAME)/Applications
	$(CP) README.md /Volumes/$(APPNAME)
	$(HDIU) detach /Volumes/$(APPNAME) -quiet
	$(HDIU) convert -format UDZO -o $(APPVDMG) -ov $(APPDMG) -quiet

dmg:	$(APPVDMG)
