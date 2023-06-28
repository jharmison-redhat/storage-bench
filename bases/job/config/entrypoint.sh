#!/bin/bash

set -euo pipefail

mkdir -p /tmp/fio-logs

fio --eta-newline=1 /jobs/bench.fio |& tee /tmp/fio-logs/output.log

oc create configmap "fio-$(date +%s)" --from-file=/tmp/fio-logs
