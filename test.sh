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
summary
