#! /bin/bash

# debug openvino detector (need to setup the environment in the command line first)
python -m debugpy --listen 5678 --wait-for-client detector.py