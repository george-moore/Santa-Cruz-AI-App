# USAGE
# python ssd_object_detection.py --prototxt MobileNetSSD_deploy.prototxt --model MobileNetSSD_deploy.caffemodel --input guitar.mp4 --output output.avi --display 0
# python ssd_object_detection.py --prototxt MobileNetSSD_deploy.prototxt --model MobileNetSSD_deploy.caffemodel --input guitar.mp4 --output output.avi --display 0 --use-gpu 1

# import the necessary packages
import numpy as np
import imutils
import cv2
import os, logging
from common import CLASSES, COLORS, format_detections

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

class Detector:
# initialize the list of class labels MobileNet SSD was trained to
# detect, then generate a set of bounding box colors for each class

  # load our serialized model from disk
  def __init__(self, use_gpu=True, confidence=0.5, people_only=True):
    self.confidence = confidence
    
    prototxt = os.path.join(os.path.dirname(__file__), "net/caffe/MobileNetSSD_deploy.prototxt")
    caffemodel = os.path.join(os.path.dirname(__file__), "net/caffe/MobileNetSSD_deploy.caffemodel")

    self.net = cv2.dnn.readNetFromCaffe(prototxt, caffemodel)
    self.class_idx = None

    # we are interested in detecting people only
    if people_only:
      self.class_idx = CLASSES.index("person")

    # check if we are going to use GPU
    if use_gpu:
      try:
        # set CUDA as the preferable backend and target
        self.net.setPreferableBackend(cv2.dnn.DNN_BACKEND_CUDA)
        self.net.setPreferableTarget(cv2.dnn.DNN_TARGET_CUDA)
        logging.info("Set preferable backend and target to CUDA...")
      except:
        logging.warn("Could not set the backend to CUDA")

  def detect(self, frame):

      # resize the frame, grab the frame dimensions, and convert it to
      # a blob
      frame = imutils.resize(frame, width=400)
      blob = cv2.dnn.blobFromImage(frame, 0.007843, (300, 300), 127.5)

      # pass the blob through the network and obtain the detections and
      # predictions
      self.net.setInput(blob)
      try:
        detections = self.net.forward()
      except:
        
        logging.warn("Could not run on GPU. Switching to CPU")
        self.net.setPreferableBackend(cv2.dnn.DNN_BACKEND_DEFAULT)
        self.net.setPreferableTarget(cv2.dnn.DNN_TARGET_CPU)

        detections = self.net.forward()

      # loop over the detections
      results = []
      for i in np.arange(0, detections.shape[2]):
        # extract the confidence (i.e., probability) associated with
        # the prediction
        confidence = detections[0, 0, i, 2]

        # filter out weak detections by ensuring the `confidence` is
        # greater than the minimum confidence
        if confidence > self.confidence:
          # extract the index of the class label from the
          # `detections`, then compute the (x, y)-coordinates of
          # the bounding box for the object
          idx = int(detections[0, 0, i, 1])

          # filter out people only if that's what we are detecting
          if self.class_idx is not None and idx != self.class_idx:
            continue
          
          [startX, startY, endX, endY] = detections[0, 0, i, 3:7].astype("float")

          results.append(format_detections(startX, startY, endX, endY, idx, confidence))

      return results
