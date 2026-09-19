#!/usr/bin/env bash
# terraform graph 生成のデフォルト設定
#
# GRAPH_* は source した側（generate-terraform-graphs.sh）が読む。単体で
# 解析すると未使用に見えるため、ファイル全体で SC2034 を切る。指示は最初の
# コマンドより前に置かないと効かない。
# shellcheck disable=SC2034
set -euo pipefail

GRAPH_OUTPUT_FILE="DEPENDENCY-GRAPH.svg"
GRAPH_RANKDIR="LR"
GRAPH_NODESEP="0.4"
GRAPH_RANKSEP="0.8"
GRAPH_SPLINES="polyline"
GRAPH_SHAPE="box"
GRAPH_FONTSIZE="10"
GRAPH_ARROW_SIZE="0.7"

load_terraform_graph_config() {
  local config_file="${1:-}"

  if [[ -z "${config_file}" ]]; then
    return 0
  fi

  if [[ ! -f "${config_file}" ]]; then
    echo "設定ファイルが見つかりません: ${config_file}" >&2
    return 1
  fi

  while IFS='=' read -r key value; do
    [[ -z "${key}" || "${key}" =~ ^[[:space:]]*# ]] && continue
    key="$(echo "${key}" | xargs)"
    value="$(echo "${value}" | xargs)"
    case "${key}" in
      OUTPUT_FILE) GRAPH_OUTPUT_FILE="${value}" ;;
      RANKDIR) GRAPH_RANKDIR="${value}" ;;
      NODESEP) GRAPH_NODESEP="${value}" ;;
      RANKSEP) GRAPH_RANKSEP="${value}" ;;
      SPLINES) GRAPH_SPLINES="${value}" ;;
      SHAPE) GRAPH_SHAPE="${value}" ;;
      FONTSIZE) GRAPH_FONTSIZE="${value}" ;;
      ARROW_SIZE) GRAPH_ARROW_SIZE="${value}" ;;
    esac
  done < "${config_file}"
}
