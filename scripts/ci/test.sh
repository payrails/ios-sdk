#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

WORKSPACE="${WORKSPACE:-Payrails.xcworkspace}"
PROJECT="${PROJECT:-Payrails.xcodeproj}"
SCHEME="${SCHEME:-Payrails}"
CONFIGURATION="${CONFIGURATION:-Debug}"
SIMULATOR_DESTINATION="${SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro,OS=latest}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build/DerivedData}"
TEST_RESULTS_PATH="${TEST_RESULTS_PATH:-.build/TestResults/PayrailsTests.xcresult}"
WORKSPACE_FILE="${WORKSPACE}/contents.xcworkspacedata"
PODS_PROJECT_FILE="Pods/Pods.xcodeproj/project.pbxproj"

CONTAINER_ARGS=()

if [[ -f "${WORKSPACE_FILE}" ]]; then
  if grep -q "Pods/Pods.xcodeproj" "${WORKSPACE_FILE}" && [[ ! -f "${PODS_PROJECT_FILE}" ]]; then
    echo "warning: workspace '${WORKSPACE}' references Pods but Pods are not present; falling back to project test."
  else
    CONTAINER_ARGS=(-workspace "${WORKSPACE}")
  fi
fi

if [[ ${#CONTAINER_ARGS[@]} -eq 0 ]] && [[ -f "${PROJECT}/project.pbxproj" ]]; then
  CONTAINER_ARGS=(-project "${PROJECT}")
fi

if [[ ${#CONTAINER_ARGS[@]} -eq 0 ]]; then
  echo "error: neither workspace '${WORKSPACE}' nor project '${PROJECT}' exists." >&2
  exit 1
fi

xcodebuild \
  "${CONTAINER_ARGS[@]}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "${SIMULATOR_DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  -resultBundlePath "${TEST_RESULTS_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  test
