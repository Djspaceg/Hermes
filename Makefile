# Do not mind me. I'm just a nice wrapper around xcodebuild(1).

XCB           = xcodebuild
XCPIPE        =
CONFIGURATION = Debug
SCHEME        = Hermes
BUILD_SETTINGS = $(XCB) $(COMMON_OPTS) -configuration $(CONFIGURATION) -scheme $(SCHEME) -showBuildSettings
HERMES_APP     = $(shell $(BUILD_SETTINGS) 2>/dev/null | sed -n 's/^[[:space:]]*CODESIGNING_FOLDER_PATH = //p' | head -1)
HERMES         = $(HERMES_APP)/Contents/MacOS/Hermes
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
	@hermes="$(HERMES)"; \
	if [ ! -x "$$hermes" ]; then \
		echo "error: Hermes executable not found at $$hermes" >&2; \
		exit 1; \
	fi; \
	exec "$$hermes"

dbg: hermes
	$(DEBUGGER) "$(HERMES)"

install: override CONFIGURATION = Release
install:
	$(XCB) $(COMMON_OPTS) -configuration $(CONFIGURATION) -scheme $(SCHEME)
	@hermes_app="$(HERMES_APP)"; \
	if [ ! -d "$$hermes_app" ]; then \
		echo "error: Hermes app not found at $$hermes_app; refusing to remove /Applications/Hermes.app" >&2; \
		exit 1; \
	fi; \
	rm -rf /Applications/Hermes.app; \
	cp -a "$$hermes_app" /Applications/

# Create an archive to share (for beta testing purposes).
archive: CONFIGURATION = Release
archive: SCHEME = 'Archive Hermes'
archive: hermes

# Used to be called 'archive'. Upload Hermes and update the website.
upload-release: CONFIGURATION = Release
upload-release: SCHEME = 'Upload Hermes Release'
upload-release: hermes

test:
	$(XCB) $(COMMON_OPTS) -scheme Hermes test

test-verbose:
	$(XCB) $(COMMON_OPTS) -scheme Hermes test | xcpretty

clean:
	$(XCB) $(COMMON_OPTS) -scheme $(SCHEME) clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/Hermes-*

.PHONY: all hermes travis run dbg archive clean install archive upload-release test test-verbose
