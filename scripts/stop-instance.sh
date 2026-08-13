
#!/usr/bin/env bash
set -euo pipefail

# Helper: stop EC2 instances listed in Terraform state
# Usage: ./scripts/stop-instance.sh [INSTANCE_NAME] [CLUSTER]
# If INSTANCE_NAME or CLUSTER are provided, stop only matching instance(s).

INSTANCE_NAME=${1:-}
CLUSTER=${2:-}

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform not found in PATH"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found in PATH"
  exit 1
fi

TMPFILE=$(mktemp)
TMPERR=$(mktemp)
cleanup() { rm -f "$TMPFILE" "$TMPERR"; }
trap cleanup EXIT

if ! terraform show -json >"$TMPFILE" 2>"$TMPERR"; then
  echo "Failed to run 'terraform show -json' or no backend/state available." >&2
  echo "terraform show stderr:" >&2
  sed -n '1,200p' "$TMPERR" >&2 || true
  echo "terraform show output (first 200 lines):" >&2
  sed -n '1,200p' "$TMPFILE" >&2 || true
  exit 1
fi

# validate JSON
if ! jq -e . "$TMPFILE" >/dev/null 2>&1; then
  echo "'terraform show -json' did not produce valid JSON:" >&2
  sed -n '1,200p' "$TMPFILE" >&2 || true
  exit 1
fi

# strip any leading non-JSON lines (some terraform wrappers print a command line)
CLEANFILE=$(mktemp)
START_LINE=$(grep -n -m1 '^[[:space:]]*[{[]' "$TMPFILE" | cut -d: -f1 || true)
if [ -n "$START_LINE" ]; then
  tail -n +"$START_LINE" "$TMPFILE" >"$CLEANFILE"
else
  cp "$TMPFILE" "$CLEANFILE"
fi

# validate JSON
if ! jq -e . "$CLEANFILE" >/dev/null 2>&1; then
  echo "'terraform show -json' did not produce valid JSON (after cleaning):" >&2
  sed -n '1,200p' "$TMPFILE" >&2 || true
  exit 1
fi

# Extract instance ids from root_module and any child_modules
if [ -n "${INSTANCE_NAME}" ] || [ -n "${CLUSTER}" ]; then
  IDS=$(jq -r --arg name "${INSTANCE_NAME}" --arg cluster "${CLUSTER}" '
    .values
    | (
        (.root_module.resources[]? // []),
        (.root_module.child_modules[]?.resources[]? // [])
      )
    | select(.type=="aws_instance")
    | select((($name=="") or ((.values.tags.Name//"")==$name)) and (($cluster=="") or ((.values.tags.Cluster//"")==$cluster)))
    | .values.id
  ' "$CLEANFILE" | paste -sd " " -)
else
  IDS=$(jq -r '
    .values
    | (
        (.root_module.resources[]? // []),
        (.root_module.child_modules[]?.resources[]? // [])
      )
    | select(.type=="aws_instance")
    | .values.id
  ' "$CLEANFILE" | paste -sd " " -)
fi
rm -f "$CLEANFILE"

if [ -z "${IDS}" ]; then
  echo "No matching aws_instance resources found in state."
  exit 0
fi

echo "Stopping instances: ${IDS}"
aws ec2 stop-instances --instance-ids ${IDS}
