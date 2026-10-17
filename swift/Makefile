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

HDIU = hdiutil
SWIFT = swift
PLB = /usr/libexec/PlistBuddy
SIPS = sips
IBT = ibtool

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

# The app is the Tuner product (the TunerAppKit target) of the package
# at the repo root, built in release, so the shipped objects are the
# tested ones
PACKAGE = ..
PRODUCT = Tuner
BINPATH = $(PACKAGE)/.build/release

$(APPBUNDLE): $(APPNAME) $(APPNAME).icns Info.plist PkgInfo $(APPNAME).entitlements
	$(RM) -rf $(APPBUNDLE)
	$(MD) -p $(APPBUNDLEMACOS)
	$(MD) -p $(APPBUNDLERESOURCES)
	$(CP) Info.plist $(APPBUNDLECONTENTS)/
	$(CP) PkgInfo $(APPBUNDLECONTENTS)/
	$(CP) $(APPNAME).icns $(APPBUNDLERESOURCES)/
	$(CP) $(APPNAME).entitlements $(APPBUNDLERESOURCES)/
	$(CP) $(APPNAME) $(APPBUNDLEMACOS)/

# Always ask the package; it rebuilds only what changed
$(APPNAME): FORCE
	cd $(PACKAGE) && $(SWIFT) build -c release --product $(PRODUCT)
	$(CP) $(BINPATH)/$(PRODUCT) $(APPNAME)

FORCE:

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
	$(RM) -f $(APPNAME).icns $(APPNAME) $(APPDMG) $(APPVDMG)

$(APPVDMG): $(APPBUNDLE)
	$(HDIU) create -size 16m -fs HFS+ -volname $(APPNAME) -ov $(APPNAME) -quiet
	$(HDIU) attach $(APPDMG) -quiet
	$(CP) -r $(APPBUNDLE) /Volumes/$(APPNAME)
	$(LN) -s /Applications /Volumes/$(APPNAME)/Applications
	$(CP) README.md /Volumes/$(APPNAME)
	$(HDIU) detach /Volumes/$(APPNAME) -quiet
	$(HDIU) convert -format UDZO -o $(APPVDMG) -ov $(APPDMG) -quiet

dmg:	$(APPVDMG)

.PHONY: dmg clean FORCE
