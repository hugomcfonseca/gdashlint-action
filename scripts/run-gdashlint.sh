#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "gdashlint-action: $*" >&2
  exit 2
}

truthy() {
  case "$1" in
    true|TRUE|True|1|yes|YES|Yes) return 0 ;;
    false|FALSE|False|0|no|NO|No|"") return 1 ;;
    *) die "invalid boolean value '$1'" ;;
  esac
}

build_args() {
  paths=()
  while IFS= read -r path; do
    if [[ -n "$path" ]]; then
      paths+=("$path")
    fi
  done <<< "$INPUT_PATHS"

  args=("$INPUT_COMMAND")
  case "$INPUT_COMMAND" in
    lint|fix|rules) ;;
    *) die "command must be one of: lint, fix, rules" ;;
  esac

  if [[ -n "$INPUT_CONFIG" ]]; then
    args+=(--config "$INPUT_CONFIG")
  fi
  if [[ -n "$INPUT_FORMAT" ]]; then
    args+=(--format "$INPUT_FORMAT")
  fi

  if [[ "$INPUT_COMMAND" == "lint" || "$INPUT_COMMAND" == "fix" ]]; then
    if [[ -n "$INPUT_FAIL_ON" ]]; then
      args+=(--fail-on "$INPUT_FAIL_ON")
    fi
    if [[ -n "$INPUT_SORT" ]]; then
      args+=(--sort "$INPUT_SORT")
    fi
    if [[ ${#paths[@]} -eq 0 ]]; then
      paths=(.)
    fi
  fi

  if [[ "$INPUT_COMMAND" == "fix" ]]; then
    if [[ -n "$INPUT_MODE" ]]; then
      args+=(--mode "$INPUT_MODE")
    fi
    if [[ -n "$INPUT_SUFFIX" ]]; then
      args+=(--suffix "$INPUT_SUFFIX")
    fi
    if truthy "$INPUT_DRY_RUN"; then
      args+=(--dry-run)
    else
      args+=(--yes)
    fi
  fi

  if [[ "$INPUT_COMMAND" == "lint" || "$INPUT_COMMAND" == "fix" ]]; then
    args+=("${paths[@]}")
  fi
}

resolve_asset_platform() {
  case "${RUNNER_OS:-Linux}" in
    Linux) asset_os=linux ;;
    macOS) asset_os=darwin ;;
    *) die "binary distribution supports Linux and macOS runners; use distribution=docker on Linux or run gdashlint directly on this runner" ;;
  esac

  case "${RUNNER_ARCH:-X64}" in
    X64) asset_arch=amd64 ;;
    ARM64) asset_arch=arm64 ;;
    *) die "unsupported runner architecture: ${RUNNER_ARCH:-unknown}" ;;
  esac
}

resolve_version() {
  version="$INPUT_VERSION"
  if [[ -n "$version" && "$version" != "latest" ]]; then
    return
  fi

  token="$INPUT_GITHUB_TOKEN"
  if [[ -z "$token" ]]; then
    token="$DEFAULT_GITHUB_TOKEN"
  fi

  auth_args=()
  if [[ -n "$token" ]]; then
    auth_args=(-H "Authorization: Bearer $token")
  fi

  release_json="$(curl -fsSL "${auth_args[@]}" https://api.github.com/repos/hugomcfonseca/gdashlint/releases/latest)"
  version="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])' <<< "$release_json")"
}

verify_checksum() {
  local archive_path="$1"
  local checksums_path="$2"
  local archive_name="$3"

  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$(dirname "$archive_path")" && grep "  ${archive_name}$" "$checksums_path" | sha256sum -c -)
    return
  fi

  if command -v shasum >/dev/null 2>&1; then
    expected="$(grep "  ${archive_name}$" "$checksums_path" | awk '{print $1}')"
    actual="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
    [[ -n "$expected" ]] || die "checksum for ${archive_name} not found"
    [[ "$actual" == "$expected" ]] || die "checksum verification failed for ${archive_name}"
    return
  fi

  die "neither sha256sum nor shasum is available for checksum verification"
}

run_binary_distribution() {
  resolve_asset_platform
  resolve_version

  asset_version="${version#v}"
  archive="gdashlint_${asset_version}_${asset_os}_${asset_arch}.tar.gz"
  base_url="https://github.com/hugomcfonseca/gdashlint/releases/download/${version}"
  install_dir="${RUNNER_TEMP:-/tmp}/gdashlint-action"
  archive_path="$install_dir/$archive"
  checksums_path="$install_dir/checksums.txt"

  mkdir -p "$install_dir"
  curl -fsSL "$base_url/$archive" -o "$archive_path"
  curl -fsSL "$base_url/checksums.txt" -o "$checksums_path"
  verify_checksum "$archive_path" "$checksums_path" "$archive"

  tar -xzf "$archive_path" -C "$install_dir"
  chmod +x "$install_dir/gdashlint"
  "$install_dir/gdashlint" "${args[@]}"
}

run_docker_distribution() {
  docker run --rm \
    -v "${GITHUB_WORKSPACE}:/work" \
    -w /work \
    "${INPUT_IMAGE}:${INPUT_VERSION}" \
    "${args[@]}"
}

build_args

case "$INPUT_DISTRIBUTION" in
  binary) run_binary_distribution ;;
  docker) run_docker_distribution ;;
  *) die "distribution must be one of: binary, docker" ;;
esac
