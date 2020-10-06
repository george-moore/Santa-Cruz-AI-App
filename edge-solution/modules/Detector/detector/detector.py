import os
import cv2
import logging
import time
from videostream import VideoStream
import numpy as np
import json
from common import display
from shared_memory import SharedMemoryManager

from flask import Flask, jsonify, request
# for HTTP/1.1 support
from werkzeug.serving import WSGIRequestHandler

app = Flask(__name__)

# 50 MB of shared memory for image storage
shm_size = 50 * 1024 * 1024
image_file_handle = "image"

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

def main_debug(displaying):
  video_file = os.path.join(os.path.dirname(__file__), "video/staircase.mp4")

  vid_stream = VideoStream(video_file, interval= 0.03)
  vid_stream.start()

  if debug:
    import ptvsd
    ptvsd.enable_attach(('0.0.0.0', 56781))
    ptvsd.wait_for_attach()
    ptvsd.break_into_debugger()

  while True:
    _, frame = vid_stream.get_frame_with_id()
    detections = detector.detect(frame)
    #logging.info(detections)

    if not displaying:
      logging.info(detections)
      continue

    frame = display(frame, detections)
    # # check to see if the output frame should be displayed to our
    # # screen
    cv2.imshow("Frame", frame)

    key = cv2.waitKey(1) & 0xFF

    if key == ord('q') or key == 27:
      break
  
  cv2.destroyAllWindows()

def get_detector_shared_manager(detector_type, device="CPU", precision="FP32", init_shared_mem=True):
  try:
    if init_shared_mem:
      shared_manager = SharedMemoryManager(image_file_handle, shm_size)
    else:
      shared_manager = None
  except:
    logging.warn("Shared memory not present")
    raise

  if detector_type == "opencv":
    from ssd_object_detection import Detector

    detector = Detector(use_gpu=True, people_only=True)
  elif detector_type == "openvino":
    from ssd_object_detection_openvino import OpenVinoDetector

    detector = OpenVinoDetector(device_name=device)
  else:
    raise ValueError("Unknown detector type")

  return shared_manager, detector

def start_app():

    # set protocol to 1.1 so we keep the connection open
    WSGIRequestHandler.protocol_version = "HTTP/1.1"

    if debug:
      import ptvsd
      ptvsd.enable_attach(('0.0.0.0', 56781))
      ptvsd.wait_for_attach()
      ptvsd.break_into_debugger()

    app.run(debug=False, host="detector", port=5010)

@app.route("/lva", methods=["POST"])
def detect_in_frame_lva():
  
  imbytes = request.get_data()
  narr = np.frombuffer(imbytes, dtype='uint8')

  img = cv2.imdecode(narr, cv2.IMREAD_COLOR)
  
  detections = detector.detect(img)

  results = dict()
  results["inferences"] = detections
  return jsonify(results)

@app.route("/detect", methods=["POST"])
def detect_in_frame():
  
  # we are sending a json object
  start = time.time()

  data = request.get_json()
  
  prep_time = time.time() - start
  shared_file = request.args.get("shared")
  shared_size = request.args.get("size")
  
  results = {'frameId': data['frameId'], 'image_name': data['image_name']}

  if  shared_file is None:
    frame = np.array(data['img']).astype('uint8')
  else:
    # by now camerastream has already initialzed shared memory
    h, w, c = tuple(map(int, shared_size.split(',')))
    im_size = h * w * c

    frame_bytes = shared_manager.ReadBytes(0, im_size)
    frame = np.frombuffer(frame_bytes, dtype=np.uint8, count=im_size).reshape((h, w, c))

  detections = detector.detect(frame)
  total_time = time.time() - start
  detection_time = total_time - prep_time 

  perf = {"imgprep": prep_time, "detection": detection_time}

  results["detections"] = detections
  results["perf"] = perf
  
  logging.info(f"detected objects: {json.dumps(results, indent=1)}")
  return jsonify(results)

if __name__== "__main__":

  from cmdline.cmd_args import parse_detector_args
  args = parse_detector_args()

  debug = args.debug
  local = args.test

  shared_manager, detector = get_detector_shared_manager(args.detector, args.device, "FP16", init_shared_mem=not local)

  if local:
    main_debug(args.display)
  else:
    start_app()  
  
