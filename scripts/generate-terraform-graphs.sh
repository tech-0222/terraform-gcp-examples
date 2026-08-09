#!/usr/bin/env bash
# examples / scenarios 配下の root module ごとに DEPENDENCY-GRAPH.svg を生成する
# GitHub Actions は使わない（ローカル実行専用）
#
# 使い方:
#   ./scripts/generate-terraform-graphs.sh --all
#   ./scripts/generate-terraform-graphs.sh --changed-from <git-ref>
#   ./scripts/generate-terraform-graphs.sh examples/01-project-service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/terraform-module-detect.sh
source "${SCRIPT_DIR}/lib/terraform-module-detect.sh"
# shellcheck source=lib/terraform-graph-config.sh
source "${SCRIPT_DIR}/lib/terraform-graph-config.sh"

CONFIG_FILE=""

usage() {
  cat <<'EOF'
Usage:
  generate-terraform-graphs.sh --all
  generate-terraform-graphs.sh --changed-from <git-ref>
  generate-terraform-graphs.sh <module-dir> [module-dir ...]

Examples:
  ./scripts/generate-terraform-graphs.sh --all
  ./scripts/generate-terraform-graphs.sh --changed-from origin/main
  ./scripts/generate-terraform-graphs.sh examples/04-compute-engine
EOF
}

require_tools() {
  terraform_module_detect_init
  CONFIG_FILE="${REPO_ROOT}/.terraform-graph.conf"
  load_terraform_graph_config "${CONFIG_FILE}"

  if ! command -v terraform >/dev/null 2>&1; then
    echo "terraform が見つかりません。" >&2
    exit 1
  fi

  if ! command -v dot >/dev/null 2>&1; then
    echo "graphviz (dot) が見つかりません。例: sudo apt install graphviz" >&2
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
    echo "root module ではありません（examples|scenarios 直下 + versions.tf が必要）: ${input}" >&2
    return 1
  fi

  echo "${module_dir}"
}

GRAPH_LOCAL_STATE_DIR=".terraform-graph"
GRAPH_BACKEND_FILE="backend.tf"
GRAPH_BACKEND_BACKUP="${GRAPH_BACKEND_FILE}.graph-bak"

setup_graph_backend() {
  if [[ ! -f "${GRAPH_BACKEND_FILE}" ]]; then
    return 0
  fi

  cp "${GRAPH_BACKEND_FILE}" "${GRAPH_BACKEND_BACKUP}"
  cat > "${GRAPH_BACKEND_FILE}" <<EOF
terraform {
  backend "local" {
    path = "${GRAPH_LOCAL_STATE_DIR}/terraform.tfstate"
  }
}
EOF
  rm -rf .terraform "${GRAPH_LOCAL_STATE_DIR}"
}

restore_graph_backend() {
  if [[ -f "${GRAPH_BACKEND_BACKUP}" ]]; then
    mv -f "${GRAPH_BACKEND_BACKUP}" "${GRAPH_BACKEND_FILE}"
  fi
  rm -rf "${GRAPH_LOCAL_STATE_DIR}"
}

generate_for_module() {
  local module_dir="$1"
  local rel="${module_dir#"${REPO_ROOT}/"}"
  local output_file="${module_dir}/${GRAPH_OUTPUT_FILE}"

  echo "Generating ${GRAPH_OUTPUT_FILE}: ${rel}"

  (
    cd "${module_dir}"
    trap restore_graph_backend EXIT
    setup_graph_backend
    if ! terraform init -input=false -reconfigure >/dev/null; then
      echo "terraform init に失敗しました: ${rel}" >&2
      exit 1
    fi
    if ! terraform graph > "${output_file}.dot"; then
      echo "terraform graph に失敗しました: ${rel}" >&2
      rm -f "${output_file}.dot"
      exit 1
    fi
    dot -Tsvg \
      "-Grankdir=${GRAPH_RANKDIR}" \
      "-Gnodesep=${GRAPH_NODESEP}" \
      "-Granksep=${GRAPH_RANKSEP}" \
      "-Gsplines=${GRAPH_SPLINES}" \
      "-Nshape=${GRAPH_SHAPE}" \
      "-Nfontsize=${GRAPH_FONTSIZE}" \
      "-Earrowsize=${GRAPH_ARROW_SIZE}" \
      "${output_file}.dot" > "${output_file}"
    rm -f "${output_file}.dot"
  )
}

main() {
  require_tools

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
      done < <(list_graph_target_dirs_from_ref "$2")
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
