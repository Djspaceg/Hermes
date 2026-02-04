# Do not mind me. I'm just a nice wrapper around xcodebuild(1).

XCB           = xcodebuild
XCPIPE        =
CONFIGURATION = Debug
SCHEME        = Hermes
DERIVED_DATA  = $(shell xcodebuild -project Hermes.xcodeproj -showBuildSettings 2>/dev/null | grep "BUILD_DIR" | head -1 | sed 's/.*= //' | xargs dirname | xargs dirname)
HERMES        = $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/Hermes.app/Contents/MacOS/Hermes
DEBUGGER      = lldb

# Build without custom SYMROOT to avoid SPM issues
COMMON_OPTS   = -project Hermes.xcodeproj

all: hermes

hermes:
	$(XCB) $(COMMON_OPTS) -configuration $(CONFIGURATION) -scheme $(SCHEME) $(XCPIPE)

travis: COMMON_OPTS += CODE_SIGN_IDENTITY= CODE_SIGNING_REQUIRED=NO
travis: XCPIPE = | xcpretty -f `xcpretty-travis-formatter`
travis: hermes

run: hermes
	$(HERMES)

dbg: hermes
	$(DEBUGGER) $(HERMES)

install:
	$(XCB) $(COMMON_OPTS) -configuration Release -scheme Hermes
	rm -rf /Applications/Hermes.app
	cp -a $(DERIVED_DATA)/Build/Products/Release/Hermes.app /Applications/

# Create an archive to share (for beta testing purposes).
archive: CONFIGURATION = Release
archive: SCHEME = 'Archive Hermes'
archive: hermes

# Used to be called 'archive'. Upload Hermes and update the website.
upload-release: CONFIGURATION = Release
upload-release: SCHEME = 'Upload Hermes Release'
upload-release: hermes

test:
	$(XCB) $(COMMON_OPTS) -scheme HermesTests test

test-verbose:
	$(XCB) $(COMMON_OPTS) -scheme HermesTests test | xcpretty

clean:
	$(XCB) $(COMMON_OPTS) -scheme $(SCHEME) clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/Hermes-*

.PHONY: all hermes travis run dbg archive clean install archive upload-release test test-verbose
