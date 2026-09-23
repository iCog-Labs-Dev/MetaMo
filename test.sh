#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

status=0
tests=()

run_in_file_dir() {
  local test_file="$1"
  shift

  local dir
  local name
  dir="$(dirname "$test_file")"
  name="$(basename "$test_file")"

  (cd "$dir" && "$@" "$name")
}

run_executable_file() {
  local test_file="$1"
  local dir
  local name

  dir="$(dirname "$test_file")"
  name="$(basename "$test_file")"

  (cd "$dir" && "./$name")
}

run_metta_file() {
  local test_file="$1"
  local dir
  local name
  local output
  local code

  dir="$(dirname "$test_file")"
  name="$(basename "$test_file")"

  output="$(cd "$dir" && petta "$name" 2>&1)"
  code=$?

  if [[ -n "$output" ]]; then
    printf '%s\n' "$output"
  fi

  if (( code != 0 )); then
    return "$code"
  fi

  if [[ "$output" == *"(Error "* ]]; then
    return 1
  fi

  return 0
}

while IFS= read -r -d '' file; do
  path="${file#./}"
  name="${path##*/}"
  stem="$name"

  if [[ "$name" == *.* ]]; then
    stem="${name%.*}"
  fi

  if [[ "$path" == "test.sh" ]]; then
    continue
  fi

  if [[ "$name" == *test || "$name" == *tests || "$stem" == *test || "$stem" == *tests ]]; then
    tests+=("$path")
  fi
done < <(
  find . \
    \( -path './.git' -o -path './.venv' -o -path './venv' -o -path './node_modules' \) -prune \
    -o -type f -print0 | sort -z
)

if (( ${#tests[@]} == 0 )); then
  echo "No test files found."
  exit 0
fi

for test_file in "${tests[@]}"; do
  echo "==> $test_file"

  case "$test_file" in
    *.metta)
      if ! command -v petta >/dev/null 2>&1; then
        echo "petta command not found; cannot run $test_file" >&2
        status=127
        continue
      fi
      run_metta_file "$test_file"
      code=$?
      ;;
    *.sh)
      run_in_file_dir "$test_file" bash
      code=$?
      ;;
    *.py)
      run_in_file_dir "$test_file" python3
      code=$?
      ;;
    *)
      if [[ -x "$test_file" ]]; then
        run_executable_file "$test_file"
        code=$?
      else
        echo "No runner configured and file is not executable: $test_file" >&2
        code=126
      fi
      ;;
  esac

  if (( code != 0 )); then
    echo "FAILED ($code): $test_file" >&2
    status=$code
  fi
done

exit "$status"
