#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

PROJECT="${PROJECT:-Payrails.xcodeproj}"
SCHEME="${SCHEME:-Payrails}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro,OS=latest}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build/DerivedData}"
TEST_LOG_PATH="${TEST_LOG_PATH:-.build/test-xcodebuild.log}"
TEST_RESULT_BUNDLE_PATH="${TEST_RESULT_BUNDLE_PATH:-.build/TestResults/PayrailsTests.xcresult}"

mkdir -p "$(dirname "${TEST_LOG_PATH}")"
mkdir -p "$(dirname "${TEST_RESULT_BUNDLE_PATH}")"

set +e
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "${SIMULATOR_DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -resultBundlePath "${TEST_RESULT_BUNDLE_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  test 2>&1 | tee "${TEST_LOG_PATH}" | (
    if command -v xcbeautify >/dev/null 2>&1; then
      xcbeautify --renderer github-actions
    else
      cat
    fi
  )
TEST_EXIT_CODE=${PIPESTATUS[0]}
set -e

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  RESULT_LINE="$(grep -E "Executed [0-9]+ tests?, with [0-9]+ failures? \([0-9]+ unexpected\) in" "${TEST_LOG_PATH}" | tail -1 || true)"
  TESTS="$(echo "${RESULT_LINE}" | sed -E 's/.*Executed ([0-9]+) tests?, with.*/\1/' || true)"
  FAILURES="$(echo "${RESULT_LINE}" | sed -E 's/.*with ([0-9]+) failures?.*/\1/' || true)"
  UNEXPECTED="$(echo "${RESULT_LINE}" | sed -E 's/.*\(([0-9]+) unexpected\).*/\1/' || true)"
  DURATION="$(echo "${RESULT_LINE}" | sed -E 's/.* in ([0-9.]+ \([0-9.]+\) seconds).*/\1/' || true)"

  [[ -n "${TESTS}" ]] || TESTS="N/A"
  [[ -n "${FAILURES}" ]] || FAILURES="N/A"
  [[ -n "${UNEXPECTED}" ]] || UNEXPECTED="N/A"
  [[ -n "${DURATION}" ]] || DURATION="N/A"

  {
    echo "### iOS Test Summary"
    echo ""
    echo "| Metric | Value |"
    echo "|---|---:|"
    echo "| Tests | ${TESTS} |"
    echo "| Failures | ${FAILURES} |"
    echo "| Unexpected | ${UNEXPECTED} |"
    echo "| Duration | ${DURATION} |"
    echo "| Exit Code | ${TEST_EXIT_CODE} |"
    echo ""
    echo "- Raw log: \`${TEST_LOG_PATH}\`"
    echo "- Result bundle: \`${TEST_RESULT_BUNDLE_PATH}\`"
  } >> "${GITHUB_STEP_SUMMARY}"
fi

exit "${TEST_EXIT_CODE}"
