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
	run_token="$${RUN_TOKEN:-}"; \
	if [ -z "$$run_token" ]; then \
		run_token=$$(/usr/bin/uuidgen); \
	fi; \
	case "$$run_token" in \
		????????-????-????-????-????????????) ;; \
		*) \
			echo "error: RUN_TOKEN must be a UUID" >&2; \
			exit 1; \
			;; \
	esac; \
	case "$$run_token" in \
		*[!0-9A-Fa-f-]*) \
			echo "error: RUN_TOKEN must be a UUID" >&2; \
			exit 1; \
			;; \
	esac; \
	pid_file="$${PID_FILE:-}"; \
	if [ -n "$$pid_file" ]; then \
		if ! : > "$$pid_file"; then \
			echo "error: cannot write PID_FILE $$pid_file" >&2; \
			exit 1; \
		fi; \
	fi; \
	HERMES_RUN_TOKEN="$$run_token" \
	HERMES_RUN_WORKTREE="$(CURDIR)" \
	HERMES_RUN_EXECUTABLE="$$hermes" \
	"$$hermes" & \
	hermes_pid=$$!; \
	runner_pid=$$$$; \
	validated_asn=; \
	while :; do \
		child_ppid=$$(/bin/ps -p "$$hermes_pid" -o ppid= 2>/dev/null | /usr/bin/tr -d '[:space:]'); \
		child_state=$$(/bin/ps -p "$$hermes_pid" -o state= 2>/dev/null | /usr/bin/tr -d '[:space:]'); \
		case "$$child_state" in \
			Z*) child_is_running=no ;; \
			*) child_is_running=yes ;; \
		esac; \
		if [ "$$child_ppid" != "$$runner_pid" ] || [ "$$child_is_running" = no ]; then \
			wait "$$hermes_pid"; \
			exit $$?; \
		fi; \
		candidate_asn=$$(/usr/bin/lsappinfo find pid="$$hermes_pid" 2>/dev/null); \
		candidate_pid=; \
		candidate_executable=; \
		if [ -n "$$candidate_asn" ]; then \
			candidate_pid=$$(/usr/bin/lsappinfo info -only pid "$$candidate_asn" 2>/dev/null | \
				sed -n 's/^"pid"=\([0-9][0-9]*\)$$/\1/p'); \
			candidate_executable=$$(/usr/bin/lsappinfo info -only executablepath "$$candidate_asn" 2>/dev/null | \
				sed -n 's/^"CFBundleExecutablePath"="\(.*\)"$$/\1/p'); \
		fi; \
		actual=$$(/bin/ps -ww -p "$$hermes_pid" -o command= 2>/dev/null); \
		process_environment=$$(/bin/ps eww -p "$$hermes_pid" -o command= 2>/dev/null); \
		child_ppid=$$(/bin/ps -p "$$hermes_pid" -o ppid= 2>/dev/null | /usr/bin/tr -d '[:space:]'); \
		child_state=$$(/bin/ps -p "$$hermes_pid" -o state= 2>/dev/null | /usr/bin/tr -d '[:space:]'); \
		case "$$process_environment" in \
			*"HERMES_RUN_TOKEN=$$run_token"*) token_matches=yes ;; \
			*) token_matches=no ;; \
		esac; \
		case "$$process_environment" in \
			*"HERMES_RUN_WORKTREE=$(CURDIR)"*) worktree_matches=yes ;; \
			*) worktree_matches=no ;; \
		esac; \
		case "$$process_environment" in \
			*"HERMES_RUN_EXECUTABLE=$$hermes"*) executable_matches=yes ;; \
			*) executable_matches=no ;; \
		esac; \
		case "$$child_state" in \
			Z*) child_is_running=no ;; \
			*) child_is_running=yes ;; \
		esac; \
		if [ "$$actual" = "$$hermes" ] && \
			[ "$$token_matches" = yes ] && \
			[ "$$worktree_matches" = yes ] && \
			[ "$$executable_matches" = yes ] && \
			[ "$$child_ppid" = "$$runner_pid" ] && \
			[ "$$child_is_running" = yes ] && \
			[ "$$candidate_pid" = "$$hermes_pid" ] && \
			[ "$$candidate_executable" = "$$hermes" ]; then \
			validated_asn="$$candidate_asn"; \
			break; \
		fi; \
		sleep 0.1; \
	done; \
	if [ -n "$$pid_file" ] && ! printf '%s\n' "$$hermes_pid" > "$$pid_file"; then \
		/usr/bin/lsappinfo kill "$$validated_asn" 2>/dev/null || true; \
		wait "$$hermes_pid" 2>/dev/null || true; \
		echo "error: cannot publish Hermes PID to $$pid_file" >&2; \
		exit 1; \
	fi; \
	echo "Hermes run identity: PID=$$hermes_pid TOKEN=$$run_token" >&2; \
	wait "$$hermes_pid"

stop:
	@pid="$${PID:-}"; \
	token="$${TOKEN:-}"; \
	case "$$pid" in \
		''|*[!0-9]*) \
			echo "error: make stop requires a numeric PID=<Hermes run PID>" >&2; \
			exit 1; \
			;; \
	esac; \
	if [ -z "$$token" ]; then \
		echo "error: make stop requires TOKEN=<Hermes run token>" >&2; \
		exit 1; \
	fi; \
	case "$$token" in \
		????????-????-????-????-????????????) ;; \
		*) \
			echo "error: TOKEN must be the UUID printed by make run" >&2; \
			exit 1; \
			;; \
	esac; \
	case "$$token" in \
		*[!0-9A-Fa-f-]*) \
			echo "error: TOKEN must be the UUID printed by make run" >&2; \
			exit 1; \
			;; \
	esac; \
	actual=$$(/bin/ps -ww -p "$$pid" -o command= 2>/dev/null); \
	case "$$actual" in \
		*/Hermes.app/Contents/MacOS/Hermes) ;; \
		*) \
			echo "error: refusing to stop PID $$pid; found $${actual:-no running process}" >&2; \
			exit 1; \
			;; \
	esac; \
	process_environment=$$(/bin/ps eww -p "$$pid" -o command= 2>/dev/null); \
	case "$$process_environment" in \
		*"HERMES_RUN_TOKEN=$$token"*) ;; \
		*) \
			echo "error: refusing to stop PID $$pid; run token does not match" >&2; \
			exit 1; \
			;; \
	esac; \
	case "$$process_environment" in \
		*"HERMES_RUN_WORKTREE=$(CURDIR)"*) ;; \
		*) \
			echo "error: refusing to stop PID $$pid; launch belongs to another worktree" >&2; \
			exit 1; \
			;; \
	esac; \
	case "$$process_environment" in \
		*"HERMES_RUN_EXECUTABLE=$$actual"*) ;; \
		*) \
			echo "error: refusing to stop PID $$pid; executable does not match launch metadata" >&2; \
			exit 1; \
			;; \
	esac; \
	asn=$$(/usr/bin/lsappinfo find pid="$$pid" 2>/dev/null); \
	if [ -z "$$asn" ]; then \
		echo "error: refusing to stop PID $$pid; no LaunchServices identity found" >&2; \
		exit 1; \
	fi; \
	asn_pid=$$(/usr/bin/lsappinfo info -only pid "$$asn" 2>/dev/null | \
		sed -n 's/^"pid"=\([0-9][0-9]*\)$$/\1/p'); \
	asn_executable=$$(/usr/bin/lsappinfo info -only executablepath "$$asn" 2>/dev/null | \
		sed -n 's/^"CFBundleExecutablePath"="\(.*\)"$$/\1/p'); \
	if [ "$$asn_pid" != "$$pid" ] || [ "$$asn_executable" != "$$actual" ]; then \
		echo "error: refusing to stop PID $$pid; LaunchServices identity does not match" >&2; \
		exit 1; \
	fi; \
	actual=$$(/bin/ps -ww -p "$$pid" -o command= 2>/dev/null); \
	process_environment=$$(/bin/ps eww -p "$$pid" -o command= 2>/dev/null); \
	case "$$process_environment" in \
		*"HERMES_RUN_TOKEN=$$token"*) ;; \
		*) \
			echo "error: refusing to stop PID $$pid; process changed before shutdown" >&2; \
			exit 1; \
			;; \
	esac; \
	case "$$process_environment" in \
		*"HERMES_RUN_WORKTREE=$(CURDIR)"*"HERMES_RUN_EXECUTABLE=$$actual"*|\
		*"HERMES_RUN_EXECUTABLE=$$actual"*"HERMES_RUN_WORKTREE=$(CURDIR)"*) ;; \
		*) \
			echo "error: refusing to stop PID $$pid; process changed before shutdown" >&2; \
			exit 1; \
			;; \
	esac; \
	if [ "$$actual" != "$$asn_executable" ]; then \
		echo "error: refusing to stop PID $$pid; process changed before shutdown" >&2; \
		exit 1; \
	fi; \
	if ! /usr/bin/lsappinfo kill "$$asn"; then \
		echo "error: failed to stop Hermes PID $$pid" >&2; \
		exit 1; \
	fi; \
	attempt=0; \
	while [ "$$attempt" -lt 100 ]; do \
		if ! asn_info=$$(/usr/bin/lsappinfo info -only pid "$$asn" 2>/dev/null); then \
			echo "error: failed to query Hermes launch identity after SIGTERM" >&2; \
			exit 1; \
		fi; \
		case "$$asn_info" in \
			"\"pid\"=$$pid") ;; \
			*'"pid"=[ NULL ]'*) exit 0 ;; \
			*) \
				echo "error: unexpected LaunchServices state after SIGTERM: $$asn_info" >&2; \
				exit 1; \
				;; \
		esac; \
		attempt=$$((attempt + 1)); \
		sleep 0.1; \
	done; \
	echo "error: Hermes PID $$pid did not exit after SIGTERM" >&2; \
	exit 1

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
	@active_pids="$$(pgrep -x xcodebuild 2>/dev/null; pgrep -x Hermes 2>/dev/null)"; \
	if [ -n "$$active_pids" ]; then \
		echo "error: refusing to start a full suite while xcodebuild or Hermes is already running" >&2; \
		for pid in $$active_pids; do \
			executable=$$(/usr/bin/proc_pidpath "$$pid" 2>/dev/null || /bin/ps -ww -p "$$pid" -o command=); \
			/bin/ps -ww -p "$$pid" -o pid=,ppid=,etime=,command= >&2; \
			echo "executable=$$executable" >&2; \
		done; \
		exit 1; \
	fi; \
	test_root="$${HERMES_TEST_ROOT_OVERRIDE:-}"; \
	remove_test_root=no; \
	if [ -z "$$test_root" ]; then \
		test_root=$$(mktemp -d /tmp/hermes-tests.XXXXXX); \
		remove_test_root=yes; \
	else \
		mkdir -p "$$test_root"; \
	fi; \
	test_root=$$(cd "$$test_root" && pwd -P); \
	canonical_tmp=$$(cd /tmp && pwd -P); \
	case "$$test_root" in \
		"$$canonical_tmp"/hermes-tests.*) ;; \
		*) \
			echo "error: refusing to run tests outside the task's /tmp root: $$test_root" >&2; \
			exit 1; \
			;; \
	esac; \
	test_home="$$test_root/home"; \
	test_state="$$test_home/Library/Application Support/Hermes"; \
	test_tmp="$$test_root/tmp"; \
	mkdir -p "$$test_state" "$$test_tmp"; \
	env \
		HOME="$$test_home" \
		CFFIXED_USER_HOME="$$test_home" \
		TMPDIR="$$test_tmp" \
		TEST_RUNNER_HOME="$$test_home" \
		TEST_RUNNER_CFFIXED_USER_HOME="$$test_home" \
		TEST_RUNNER_HERMES_TEST_ROOT="$$test_root" \
		TEST_RUNNER_HERMES_TEST_CANONICAL_TMP="$$canonical_tmp" \
		TEST_RUNNER_HERMES_TEST_HOME="$$test_home" \
		TEST_RUNNER_HERMES_TEST_STATE_PATH="$$test_state" \
		TEST_RUNNER_TMPDIR="$$test_tmp" \
		TEST_RUNNER_HERMES_UX_EVIDENCE_PATH="$${HERMES_UX_EVIDENCE_PATH:-}" \
		$(XCB) $(COMMON_OPTS) -scheme Hermes test; \
	test_status=$$?; \
	if [ "$$remove_test_root" = yes ] && [ "$${HERMES_TEST_KEEP_ROOT:-0}" != 1 ]; then \
		rm -rf "$$test_root"; \
	fi; \
	exit "$$test_status"

test-verbose: test

clean:
	$(XCB) $(COMMON_OPTS) -scheme $(SCHEME) clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/Hermes-*

.PHONY: all hermes travis run stop dbg archive clean install archive upload-release test test-verbose
