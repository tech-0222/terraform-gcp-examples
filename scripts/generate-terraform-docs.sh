#!/usr/bin/env bash
# Basic-Examples / Advanced-Examples 配下の root module ごとに PARAMETER.md を生成する
# GitHub Actions は使わない（ローカル実行専用）
#
# 使い方:
#   ./scripts/generate-terraform-docs.sh --all
#   ./scripts/generate-terraform-docs.sh --changed-from <git-ref>
#   ./scripts/generate-terraform-docs.sh Basic-Examples/01-project-service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/terraform-module-detect.sh
source "${SCRIPT_DIR}/lib/terraform-module-detect.sh"

CONFIG_FILE=""

usage() {
  cat <<'EOF'
Usage:
  generate-terraform-docs.sh --all
  generate-terraform-docs.sh --changed-from <git-ref>
  generate-terraform-docs.sh <module-dir> [module-dir ...]

Examples:
  ./scripts/generate-terraform-docs.sh --all
  ./scripts/generate-terraform-docs.sh --changed-from origin/main
  ./scripts/generate-terraform-docs.sh Basic-Examples/01-project-service
EOF
}

require_terraform_docs() {
  terraform_module_detect_init
  CONFIG_FILE="${REPO_ROOT}/.terraform-docs.yml"

  if ! command -v terraform-docs >/dev/null 2>&1; then
    echo "terraform-docs が見つかりません。インストール例: https://terraform-docs.io/user-guide/installation/" >&2
    exit 1
  fi

  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "設定ファイルが見つかりません: ${CONFIG_FILE}" >&2
    exit 1
  fi
}

normalize_module_dir() {
  local input="$1"
  local module_dir

  if [[ "${input}" != /* ]]; then
    module_dir="${REPO_ROOT}/${input}"
  else
    module_dir="${input}"
  fi

  module_dir="$(cd "${module_dir}" && pwd)"

  if ! is_root_module_dir "${module_dir}"; then
    echo "root module ではありません（Basic-Examples|Advanced-Examples 直下 + versions.tf が必要）: ${input}" >&2
    return 1
  fi

  echo "${module_dir}"
}

generate_for_module() {
  local module_dir="$1"
  local rel="${module_dir#"${REPO_ROOT}/"}"
  echo "Generating PARAMETER.md: ${rel}"
  terraform-docs --config "${CONFIG_FILE}" "${module_dir}"
}

main() {
  require_terraform_docs

  local -a module_dirs=()

  if [[ $# -eq 0 ]]; then
    usage >&2
    exit 1
  fi

  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --all)
      while IFS= read -r module_dir; do
        module_dirs+=("${module_dir}")
      done < <(list_all_root_module_dirs)
      ;;
    --changed-from)
      [[ $# -ge 2 ]] || {
        echo "--changed-from には git ref を指定してください" >&2
        exit 1
      }
      while IFS= read -r module_dir; do
        [[ -n "${module_dir}" ]] || continue
        module_dirs+=("${module_dir}")
      done < <(list_docs_target_dirs_from_ref "$2")
      ;;
    *)
      local arg
      for arg in "$@"; do
        module_dirs+=("$(normalize_module_dir "${arg}")")
      done
      ;;
  esac

  if [[ ${#module_dirs[@]} -eq 0 ]]; then
    echo "生成対象の root module がありません"
    exit 0
  fi

  local -A seen=()
  local module_dir
  local count=0

  for module_dir in "${module_dirs[@]}"; do
    [[ -n "${module_dir}" ]] || continue
    [[ -n "${seen[${module_dir}]+x}" ]] && continue
    seen["${module_dir}"]=1
    generate_for_module "${module_dir}"
    count=$((count + 1))
  done

  echo "Done: ${count} module(s)"
}

main "$@"
