#!/bin/bash
# run camera stream: no args

cd /camera-stream
ARGS=$@

# check for openvino
[[ ! -z "$INTEL_OPENVINO_DIR" ]] && source $INTEL_OPENVINO_DIR/bin/setupvars.sh

python3 $ARGS