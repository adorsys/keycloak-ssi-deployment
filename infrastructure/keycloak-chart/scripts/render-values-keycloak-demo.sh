#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_FILE="${CHART_DIR}/values-keycloak-demo.yaml.tpl"
OUTPUT_FILE="${CHART_DIR}/values-keycloak-demo.yaml"

PLUGIN_VERSION="${1:-${PLUGIN_VERSION:-1.1.6}}"

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
  echo "Template not found: ${TEMPLATE_FILE}" >&2
  exit 1
fi

python3 - "${TEMPLATE_FILE}" "${OUTPUT_FILE}" "${PLUGIN_VERSION}" <<'PY'
import sys
from pathlib import Path

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
plugin_version = sys.argv[3]

content = template_path.read_text(encoding="utf-8")
content = content.replace("${PLUGIN_VERSION}", plugin_version)
output_path.write_text(content, encoding="utf-8")
PY

echo "Generated ${OUTPUT_FILE} with PLUGIN_VERSION=${PLUGIN_VERSION}"
