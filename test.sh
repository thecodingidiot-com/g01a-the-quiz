#!/bin/bash
# g01a — The Quiz / test.sh
#
# Tests the terminal quiz game.
# Copy this file into your working directory alongside libtci.a,
# libtciutil.a, game.h, and all game source files, then run:
#
#   bash test.sh

set -o pipefail

# ── colour ────────────────────────────────────────────────────────────────────

if [[ ! -t 1 ]]; then
    C_GREEN=""
    C_RED=""
    C_BOLD=""
    C_RESET=""
else
    C_GREEN="\033[0;32m"
    C_RED="\033[0;31m"
    C_BOLD="\033[1m"
    C_RESET="\033[0m"
fi

# ── state ─────────────────────────────────────────────────────────────────────

pass_count=0
fail_count=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="${SCRIPT_DIR}/fixtures"
GAME=./game
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

# ── helpers ───────────────────────────────────────────────────────────────────

hr() {
    echo "────────────────────────────────────────────────────────────────"
}

banner() {
    hr
    echo "  g01a — The Quiz / test.sh"
    hr
}

pass() {
    local label="$1"
    printf "  ${C_GREEN}PASS${C_RESET}  %s\n" "$label"
    pass_count=$((pass_count + 1))
}

fail() {
    local label="$1"
    local pattern="$2"
    local got="$3"
    printf "  ${C_RED}FAIL${C_RESET}  %s\n" "$label"
    if [[ -n "$pattern" ]]; then
        printf "    expected output to contain: %s\n" "$pattern"
        printf "    last 3 lines of output:\n"
        printf '%s' "$got" | tail -3 | while IFS= read -r line; do
            printf "      %s\n" "$line"
        done
    fi
    fail_count=$((fail_count + 1))
}

check_contains() {
    local label="$1"
    local output="$2"
    local pattern="$3"
    if printf '%s' "$output" | grep -qF "$pattern"; then
        pass "$label"
    else
        fail "$label" "$pattern" "$output"
    fi
}

# ── pre-flight ────────────────────────────────────────────────────────────────

preflight() {
    local ok=1
    for tool in gcc make; do
        if ! command -v "$tool" &>/dev/null; then
            echo "error: $tool is not installed" >&2
            ok=0
        fi
    done
    if [[ ! -f Makefile ]]; then
        echo "error: Makefile not found — run from your working directory" >&2
        ok=0
    fi
    if [[ ! -f libtci.a ]]; then
        echo "error: libtci.a not found — copy it from your c03 build" >&2
        ok=0
    fi
    if [[ ! -f libtciutil.a ]]; then
        echo "error: libtciutil.a not found — copy it from your c03 build" >&2
        ok=0
    fi
    if [[ ! -d "$FIXTURES" ]]; then
        echo "error: fixtures/ not found — keep the g01a-the-quiz clone alongside your working directory" >&2
        ok=0
    fi
    if [[ $ok -eq 0 ]]; then
        exit 1
    fi
}

# ── build ─────────────────────────────────────────────────────────────────────

build() {
    echo ""
    echo "${C_BOLD}  Building${C_RESET}"
    echo ""
    local build_out
    build_out=$(make re 2>&1)
    local build_exit=$?
    printf '%s\n' "$build_out" | sed 's/^/  /'
    echo ""
    if [[ $build_exit -eq 0 ]]; then
        pass "make re"
    else
        fail "make re" "" ""
        echo "  Build failed — aborting tests."
        exit 1
    fi
}

# ── game tests ────────────────────────────────────────────────────────────────

run_tests() {
    local output
    echo ""
    echo "${C_BOLD}  Game tests${C_RESET}"
    echo ""

    # test 1: full win — correct answers to all 15 questions
    # fixtures/test-questions.txt has answer index 0 for every question,
    # so 'A' is always correct regardless of shuffle order.
    output=$(printf 'A\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\n' \
        | "$GAME" "${FIXTURES}/test-questions.txt" 2>&1)
    check_contains "full win (15 correct answers)" \
        "$output" "Congratulations"

    # test 2: early loss — wrong answer on question 3 (before the first safe level)
    output=$(printf 'A\nA\nB\n' \
        | "$GAME" "${FIXTURES}/test-questions.txt" 2>&1)
    check_contains "early loss (wrong at Q3, no safe level reached)" \
        "$output" "You leave with £0."

    # test 3: 50:50 lifeline — use lifeline '1' on question 8, then answer correctly
    # input: 7 A's (Q1–7), then '1' + 'A' for Q8 (lifeline then answer), then 7 A's (Q9–15)
    output=$(printf 'A\nA\nA\nA\nA\nA\nA\n1\nA\nA\nA\nA\nA\nA\nA\nA\n' \
        | "$GAME" "${FIXTURES}/test-questions.txt" 2>&1)
    check_contains "50:50 lifeline applied on Q8" \
        "$output" "50:50 — two wrong answers removed."
    check_contains "game won after using 50:50" \
        "$output" "Congratulations"

    # test 4: walk away — walk at Q11 after passing the £32,000 safe level (Q10)
    # Q10 (index 9) has SAFE[9]=1, so safe_level becomes 9 after Q10.
    # Walking at Q11 (level=10) → display_walkaway(10) → PRIZES[9] = "£32,000".
    output=$(printf 'A\nA\nA\nA\nA\nA\nA\nA\nA\nA\nW\n' \
        | "$GAME" "${FIXTURES}/test-questions.txt" 2>&1)
    check_contains "walk away at Q11 (banked £32,000)" \
        "$output" "You walk away with £32,000."

    # test 5: a file that is not a question file must be refused, not crash.
    # This is a regression test. load_questions() used to ask "does this line
    # have five fields?" by testing fields[4] -- an index past the end of any
    # shorter array, so the answer was whatever heap memory happened to sit
    # there. Feeding it a *text* file usually read NULL and looked fine;
    # feeding it a binary read garbage, passed the check, and segfaulted on
    # the NULL field right after. So the fixture here is the game's own
    # binary, which is exactly what a mistyped argument lands on.
    "$GAME" "$GAME" >/dev/null 2>&1
    local status=$?
    if [ "$status" -ge 128 ]; then
        fail "a non-question file is refused, not fatal" \
            "clean exit" "killed by signal $((status - 128))"
    else
        pass "a non-question file is refused, not fatal"
    fi

    # ...and the same for a line with too few fields, the in-bounds case of
    # the same mistake.
    printf 'q|a|b|c\nq|a|b|c\n' > "$WORK_DIR/short.txt"
    "$GAME" "$WORK_DIR/short.txt" >/dev/null 2>&1
    status=$?
    if [ "$status" -ge 128 ]; then
        fail "a short question line is skipped, not fatal" \
            "clean exit" "killed by signal $((status - 128))"
    else
        pass "a short question line is skipped, not fatal"
    fi
}

# ── summary ───────────────────────────────────────────────────────────────────

summary() {
    local total=$((pass_count + fail_count))
    echo ""
    hr
    printf "  %d / %d tests passed\n" "$pass_count" "$total"
    hr
    echo ""
    if [[ $fail_count -gt 0 ]]; then
        exit 1
    fi
}

# ── main ──────────────────────────────────────────────────────────────────────

banner
preflight
build
run_tests
# ── leak report ─────────────────────────────────────────────────────────────
#
# Runs one representative invocation under valgrind and REPORTS what it finds.
# It never changes the pass/fail count. A leak is something to look at, not a
# reason to refuse your work — but you should see it, because a program that
# leaks is a program that will eventually be killed by the machine it runs on.
#
# Leaks are split by whose code lost the memory. A loss record whose stack
# names one of your own .c files is yours. One that lives entirely inside
# SDL, Mesa or glibc is not, and there is nothing for you to fix there.

leak_report() {
    local label="$1"; shift
    local log="${WORK_DIR:-/tmp}/leaks.$$.log"
    local mine=0 theirs=0 rec frames

    if ! command -v valgrind >/dev/null 2>&1; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: valgrind is not installed, skipping\n" "$label"
        return 0
    fi

    valgrind --leak-check=full --show-leak-kinds=definite,indirect \
             --error-exitcode=0 --log-file="$log" "$@" >/dev/null 2>&1

    if [[ ! -s "$log" ]]; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: valgrind produced no output\n" "$label"
        return 0
    fi

    # Split the log into loss records and ask, of each, whether any frame
    # points at a source file sitting in this directory.
    while IFS= read -r rec; do
        frames=$(sed -n "${rec}"',/^==[0-9]*== *$/p' "$log")
        # Every record carries valgrind's own malloc frame; that is not yours.
        # A frame is yours only if it names a source file sitting right here.
        local f owned=0
        for f in $(grep -oE '\(([A-Za-z0-9_-]+\.c):[0-9]+\)' <<<"$frames" \
                   | tr -d '()' | cut -d: -f1 | sort -u); do
            [[ "$f" == vg_replace_malloc.c ]] && continue
            [[ -f "$f" ]] && owned=1
        done
        if (( owned )); then
            mine=$((mine + 1))
            if (( mine == 1 )); then
                printf "  ${C_RED}LEAK${C_RESET}  %s — memory lost by your code:\n" "$label"
            fi
            grep -E 'bytes in [0-9,]+ blocks are (definitely|indirectly)' <<<"$frames" \
                | sed 's/^==[0-9]*== /        /'
            grep -oE '\(([A-Za-z0-9_-]+\.c:[0-9]+)\)' <<<"$frames" \
                | grep -v vg_replace_malloc | head -3 | tr -d '()' \
                | sed 's/^/          at /'
        else
            theirs=$((theirs + 1))
        fi
    done < <(grep -nE 'bytes in [0-9,]+ blocks are (definitely|indirectly) lost' "$log" | cut -d: -f1)

    if (( mine == 0 )); then
        printf "  ${C_GREEN}OK${C_RESET}    %s — no memory lost by your code" "$label"
        if (( theirs > 0 )); then
            printf ' (%d leak(s) inside libraries you did not write)' "$theirs"
        fi
        printf '\n'
    else
        printf '        this does not fail the tester — fix it anyway\n'
    fi
    rm -f "$log"
    return 0
}

# The graphical chapters run until you quit them, and a program killed
# mid-loop reports everything it has not freed yet as "lost" -- which would be
# a lie. So this starts a virtual display, lets the program run, sends it a
# 'q', and measures the clean exit.
leak_report_gui() {
    local label="$1"; shift
    if ! command -v valgrind >/dev/null 2>&1; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: valgrind is not installed, skipping\n" "$label"
        return 0
    fi
    if ! command -v xvfb-run >/dev/null 2>&1 || ! command -v xte >/dev/null 2>&1; then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: needs xvfb-run and xte for a clean exit, skipping\n" "$label"
        return 0
    fi
    printf "  ${C_BOLD}....${C_RESET}  %s: running under valgrind, this takes a minute\n" "$label"
    local inner="${WORK_DIR:-/tmp}/leak_gui.$$.sh"
    {
        echo "C_GREEN=\"${C_GREEN}\"; C_RED=\"${C_RED}\"; C_BOLD=\"${C_BOLD}\"; C_RESET=\"${C_RESET}\""
        echo "WORK_DIR=\"${WORK_DIR:-/tmp}\""
        declare -f leak_report
        echo '( sleep 12; xte "key q" 2>/dev/null; sleep 5; xte "key q" 2>/dev/null ) &'
        printf 'leak_report %q' "$label"
        printf ' %q' "$@"
        printf '\n'
    } > "$inner"
    timeout 240 xvfb-run -a bash "$inner"
    local rc=$?
    rm -f "$inner"
    if (( rc == 124 )); then
        printf "  ${C_BOLD}NOTE${C_RESET}  %s: the program never exited, so there is nothing honest to measure\n" "$label"
        printf "        (a program killed mid-loop reports everything it holds as lost)\n"
    fi
    return 0
}

echo
printf 'A\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\nA\n' \
    | leak_report "game" "$GAME" "${FIXTURES}/test-questions.txt"

summary
