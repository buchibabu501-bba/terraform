
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

if [ -n "${INSTANCE_NAME}" ] || [ -n "${CLUSTER}" ]; then
  IDS=$(terraform show -json \
    | jq -r --arg name "${INSTANCE_NAME}" --arg cluster "${CLUSTER}" \
      '.values.root_module.resources[]
       | select(.type=="aws_instance")
       | select((($name=="") or ((.values.tags.Name//"")==$name)) and (($cluster=="") or ((.values.tags.Cluster//"")==$cluster)))
       | .values.id' \
    | paste -sd " ")
else
  IDS=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="aws_instance") | .values.id' | paste -sd " ")
fi

if [ -z "${IDS}" ]; then
  echo "No matching aws_instance resources found in state."
  exit 0
fi

echo "Stopping instances: ${IDS}"
aws ec2 stop-instances --instance-ids ${IDS}
