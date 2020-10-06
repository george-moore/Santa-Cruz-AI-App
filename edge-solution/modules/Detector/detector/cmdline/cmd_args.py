import os, argparse

def parse_detector_args():
  ap = argparse.ArgumentParser()
  ap.add_argument("--test", default=False, action="store_true", help="Test detector functionality")
  ap.add_argument("--display", default=False, action="store_true", help="Should we display detection results")
  ap.add_argument("--debug", default=False, action="store_true", help="Invoke remote debugger")
  ap.add_argument("--detector", default="opencv", help="Detector: opencv or openvino")
  ap.add_argument("--device", default="CPU", help="Device: CPU, GPU, MYRIAD")
  args = ap.parse_args()
  return args