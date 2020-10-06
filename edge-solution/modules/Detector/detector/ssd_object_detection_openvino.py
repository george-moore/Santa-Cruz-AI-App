#!/usr/bin/env python
"""
 Copyright (c) 2018 Intel Corporation

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
"""
import os
import cv2
import numpy as np
import logging
from openvino.inference_engine import IECore
from common import CLASSES, format_detections

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

class OpenVinoDetector:
  def __init__(self, device_name="CPU", threshold=0.5, people_only=False, precision='FP32'):

    model_path = f"net/openvino/{precision}"
    model_name = os.path.join(model_path, "mobilenet-ssd.xml")
    model_weights = os.path.join(model_path, "mobilenet-ssd.bin")

    ie = IECore()
    self.net = ie.read_network(model=model_name, weights=model_weights)
    logging.info("Read SSD model")

    self.exec_net = ie.load_network(network=self.net, device_name=device_name)
    logging.info(f"Loaded model to {device_name}")

    logging.info(f"Model precision: {precision}")
    logging.info(f"Detection threshold: {threshold}")

    self.threshold = threshold
    self.class_idx = None

    # we are interested in detecting people only
    if people_only:
      self.class_idx = CLASSES.index("person")
    

    # extract input info from the model
    for input_key in self.net.input_info:
      # only 1 input
      self.input_name = input_key 
      logging.info(f"input shape: {self.net.input_info[input_key].input_data.shape}")
      logging.info(f"input key: {input_key}")

      if len(self.net.input_info[input_key].input_data.layout) == 4:
        self.n, self.c, self.h, self.w = self.net.input_info[input_key].input_data.shape

      logging.info("Batch size is {}".format(self.net.batch_size))
      self.net.input_info[input_key].precision = 'U8'

  def detect(self, frame):
    # need it to be in CHW format
    image = cv2.resize(frame, (self.w, self.h))
    image = image.transpose((2, 0, 1))
    image = image[np.newaxis, :]

    # --------------------------- 4. Configure input & output ---------------------------------------------
    # --------------------------- Prepare input blobs -----------------------------------------------------
    out_blob = next(iter(self.net.outputs))

    data = dict()
    data[self.input_name] = image

    # --------------------------- Performing inference ----------------------------------------------------
    res = self.exec_net.infer(inputs=data)
    # -----------------------------------------------------------------------------------------------------

    # --------------------------- Read and postprocess output ---------------------------------------------
    res = res[out_blob]
    data = res[0][0]

    results = []

    for _, proposal in enumerate(data):
      if proposal[2] > self.threshold:
          idx = np.int(proposal[1])
          # filter out people only if that's what we are detecting
          if self.class_idx is not None and idx != self.class_idx:
              continue

          confidence = proposal[2]
          xmin = proposal[3]
          ymin = proposal[4]
          xmax = proposal[5]
          ymax = proposal[6]

          results.append(format_detections(xmin, ymin, xmax, ymax, idx, confidence))

    return results