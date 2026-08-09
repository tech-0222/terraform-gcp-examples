#!/usr/bin/env bash
# Basic-Examples / Advanced-Examples 配下の root module 検知ライブラリ
# （terraform-docs / terraform-graph で共有）
set -euo pipefail

terraform_module_detect_init() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  BASIC_ROOT="${REPO_ROOT}/Basic-Examples"
  ADVANCED_ROOT="${REPO_ROOT}/Advanced-Examples"
}

_normalize_path() {
  local path="$1"
  if [[ "${path}" == "${REPO_ROOT}"/* ]]; then
    path="${path#"${REPO_ROOT}/"}"
  fi
  printf '%s\n' "${path}"
}

# Root module: Basic-Examples/<name> or Advanced-Examples/<name> with versions.tf
# (main.tf が無いサンプルもあるため versions.tf を判定に使う)
is_root_module_dir() {
  local module_dir="$1"
  [[ -f "${module_dir}/versions.tf" ]] || return 1
  [[ "${module_dir}" == "${BASIC_ROOT}"/* || "${module_dir}" == "${ADVANCED_ROOT}"/* ]] || return 1
  # 直下1階層のみ（ネストした modules は対象外）
  local parent
  parent="$(dirname "${module_dir}")"
  [[ "${parent}" == "${BASIC_ROOT}" || "${parent}" == "${ADVANCED_ROOT}" ]]
}

list_all_root_module_dirs() {
  local root
  for root in "${BASIC_ROOT}" "${ADVANCED_ROOT}"; do
    [[ -d "${root}" ]] || continue
    find "${root}" -mindepth 2 -maxdepth 2 -name 'versions.tf' -not -path '*/.terraform/*' | sort | while IFS= read -r versions_tf; do
      dirname "${versions_tf}"
    done
  done
}

resolve_root_module_dir_from_path() {
  local path
  path="$(_normalize_path "$1")"

  if [[ "${path}" != Basic-Examples/* && "${path}" != Advanced-Examples/* ]]; then
    return 0
  fi

  # Basic-Examples/00-provider-check/foo.tf -> Basic-Examples/00-provider-check
  local rel="${path}"
  local top="${rel%%/*}"
  local name
  name="$(echo "${rel}" | cut -d/ -f2)"
  [[ -n "${name}" && "${name}" != "${rel}" ]] || return 0

  local module_dir="${REPO_ROOT}/${top}/${name}"
  if is_root_module_dir "${module_dir}"; then
    printf '%s\n' "${module_dir}"
  fi
}

list_changed_root_module_dirs_from_ref() {
  local base_ref="$1"

  if ! git rev-parse --verify "${base_ref}" >/dev/null 2>&1; then
    echo "比較対象の ref が見つかりません: ${base_ref}" >&2
    return 1
  fi

  while IFS= read -r changed_path; do
    [[ -n "${changed_path}" ]] || continue
    resolve_root_module_dir_from_path "${changed_path}"
  done < <(git diff --name-only "${base_ref}" HEAD -- 'Basic-Examples/**/*.tf' 'Advanced-Examples/**/*.tf' | sort -u) | sort -u
}

requires_all_docs_targets_from_ref() {
  local base_ref="$1"
  git diff --name-only "${base_ref}" HEAD |
    grep -qE '^(\.terraform-docs\.yml|scripts/generate-terraform-docs\.sh|scripts/lib/terraform-module-detect\.sh)$'
}

requires_all_graph_targets_from_ref() {
  local base_ref="$1"
  git diff --name-only "${base_ref}" HEAD |
    grep -qE '^(\.terraform-graph\.conf|scripts/generate-terraform-graphs\.sh|scripts/lib/terraform-graph-config\.sh|scripts/lib/terraform-module-detect\.sh)$'
}

list_docs_target_dirs_from_ref() {
  local base_ref="$1"
  if requires_all_docs_targets_from_ref "${base_ref}"; then
    list_all_root_module_dirs
    return 0
  fi
  list_changed_root_module_dirs_from_ref "${base_ref}"
}

list_graph_target_dirs_from_ref() {
  local base_ref="$1"
  if requires_all_graph_targets_from_ref "${base_ref}"; then
    list_all_root_module_dirs
    return 0
  fi
  list_changed_root_module_dirs_from_ref "${base_ref}"
}
