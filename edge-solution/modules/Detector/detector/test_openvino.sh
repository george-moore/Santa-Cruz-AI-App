#! /bin/bash

source $INTEL_OPENVINO_DIR/bin/setupvars.sh
python3 detector.py --test --device MYRIAD --detector openvino