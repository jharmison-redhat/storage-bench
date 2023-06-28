#!/bin/bash

set -euo pipefail

cd "$(dirname "$(realpath "$0")")"

# defaults
delete=false
overlay=default

# handle args
while (( ${#} > 0 )); do
    case "$1" in
        -d|--delete)
            delete=true
            ;;
        -h|--help)
            echo "usage: $0 [-d|--delete]|[-h|--help] [OVERLAY]" >&2
            exit 0
            ;;
        *)
            overlay="$1"
            ;;
    esac; shift
done

# create job
oc apply -k "overlays/$overlay"

# wait this long, in seconds, for job completion
timeout=1800
# how often to check
step=5
# start with 0 seconds spent
time=0

function run_step() {
    # evaluate if we have timed out, otherwise sleep and increment time by step
    if (( time >= timeout )); then
        echo
        echo "Timed out waiting for job." >&2
        exit 1
    fi
    sleep $step
    (( time += step ))
    echo -n .
}

echo -n "Waiting for job completion."
# when field doesn't exist at all
while [ -z "$(oc get job -n storage-bench storage-bench -ojsonpath='{.status.succeeded}')" ]; do
    run_step
done
# when runs are not showing complete
while (( $(oc get job -n storage-bench storage-bench -ojsonpath='{.status.succeeded}') < 1 )); do
    run_step
done
echo

# recover configmap of log outputs
cm="$(oc get $(oc logs job/storage-bench -n storage-bench | tail -1 | cut -d' ' -f1) -n storage-bench -ojson)"

# save in configmap name (unix timestamped)
dir="logs/$(echo "$cm" | jq -r '.metadata.name')"
mkdir -p "$dir"

# pull logs from configmap
for log in $(echo "$cm" | jq -r '.data | keys[]'); do
    echo "$cm" | jq -r '.data["'"$log"'"]' > "$dir/$log"
done

# clean up if asked for
if $delete; then
    oc delete -k "overlays/$overlay" --wait=true
fi
