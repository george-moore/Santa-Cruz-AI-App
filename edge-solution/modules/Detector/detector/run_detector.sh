#! /bin/bash

cd /detector
ARGS=$@

# check for openvino
if [[ ! -z "$INTEL_OPENVINO_DIR" ]]; then 
    source $INTEL_OPENVINO_DIR/bin/setupvars.sh
    ARGS="$ARGS --device MYRIAD --detector openvino"
fi

python3 $ARGS