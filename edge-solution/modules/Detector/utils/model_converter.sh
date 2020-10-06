#! /bin/bash

# run model converter on our mobilenet model
python3 mo.py --framework caffe --data_type FP32 --input_shape [1,3,300,300] --input data --mean_values data[127.5,127.5,127.5] --scale_values data[127.50223128904757] \
    --output detection_out --input_model $0\mobilenet-ssd.caffemodel --input_proto $0\mobilenet-ssd.prototxt --output_dir $1