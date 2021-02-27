import cv2
import os
import logging
import time
import json
import datetime
from azure.storage.blob import BlobServiceClient
import requests
import threading
from streamer.videostream import VideoStream
import imutils
import mmap

from messaging.iotmessenger import IoTInferenceMessenger

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

camera_config = None
received_twin_patch = False
twin_patch = None
shared_memory = None
shared_memory_name='image'
shared_memory_size = 50 * 1024 * 1024

def parse_twin(data):
  global camera_config, received_twin_patch

  logging.info(f"Retrieved updated properties: {data}")
  logging.info(data)

  if 'desired' in data:
    data = data['desired']

  if "cameras" in data:
    cams = data["cameras"].copy()
  blob = None

  # if blob is not specified we will message
  # the images to the IoT hub
  if "blob" in data:
    blob = data["blob"]

  camera_config = dict()
    
  camera_config["cameras"] = cams.copy()
  camera_config["blob"] = blob
  camera_config["shared_memory"] = data["shared_memory"]  if  "shared_memory" in data else False

  logging.info(f"config set: {camera_config}")
  received_twin_patch = False

def module_twin_callback(client):

  global twin_patch, received_twin_patch

  while True:
    # for debugging try and establish a connection
    # otherwise we don't care. If it can't connect let iotedge restart it
    twin_patch = client.receive_twin_desired_properties_patch()
    received_twin_patch = True

def main():
  global camera_config, shared_memory
  
  # Shared memory
  fd = None

  messenger = IoTInferenceMessenger()
  client = messenger.client

  twin_update_listener = threading.Thread(target=module_twin_callback, args=(client,))
  twin_update_listener.daemon = True
  twin_update_listener.start()

    # Should be properly asynchronous, but since we don't change things often
  # Wait for it to come back from twin update the very first time
  for i in range(20):
    if camera_config is None:
      time.sleep(0.5)
    break
  
  if camera_config is None:
    payload = client.get_twin()
    parse_twin(payload)

  logging.info("Created camera configuration from twin")

  if camera_config["shared_memory"]:
    fd = open(f'/dev/shm/{shared_memory_name}', 'wb+')
    fd.write(bytearray(shared_memory_size))
    shared_memory = mmap.mmap(fd.fileno(), shared_memory_size, mmap.MAP_SHARED, mmap.PROT_WRITE)
    logging.info("Using shared memory!")
    
  while True:
    spin_camera_loop(messenger, fd)
    parse_twin(twin_patch)

def spin_camera_loop(messenger, shared_mem_file):
  
  intervals_per_cam = dict()

  if camera_config["blob"] is not None:
    blob_service_client = BlobServiceClient.from_connection_string(camera_config["blob"])
    logging.info(f"Created blob service client: {blob_service_client.account_name}")

  while not received_twin_patch:

    for key, cam in camera_config["cameras"].items():

      if not cam["enabled"]:
          continue

      curtime = time.time()
      
      if key not in intervals_per_cam:
        intervals_per_cam[key] = dict()
        current_source = intervals_per_cam[key]
        current_source['timer'] = 0
        current_source['rtsp'] = cam['rtsp']
        current_source['interval'] = float(cam['interval'])
        current_source['video'] = VideoStream(cam['rtsp'], float(cam['interval']))
        current_source['video'].start()

      # this will keep track of how long we need to wait between
      # bursts of activity

      # find the current video streamer 
      for keycurrent, camcurrent in intervals_per_cam.items():
          if camcurrent['rtsp'] == cam['rtsp']:
              video_streamer = camcurrent['video']
      # video_streamer = current_source['video']

      # TODO fix multi video sources time issue.
      # not enough time has passed since the last collection
      if curtime - current_source['timer'] < float(cam['interval']):
          continue

      current_source['timer'] = curtime

      # block until we get something
      frame_id, img = video_streamer.get_frame_with_id()
      if img is None:
        logging.warn("No frame retrieved. Is video running?")
        continue

      logging.info(f"Grabbed frame {frame_id} from {cam['rtsp']}")

      camId = f"{cam['space']}/{key}"

      # send to blob storage and retrieve the timestamp by which we will identify the video
      curtimename = None
      perf = None
      if camera_config["blob"] is not None:
          start_upload = time.time()
          curtimename, _ = send_img_to_blob(blob_service_client, img, camId)
          total_upload = time.time() - start_upload
          perf = {"upload": total_upload}

      detections = []
      
      if cam['detector'] is not None and cam['inference'] is not None and cam['inference']:
        start_inf = time.time()
        res = infer(cam['detector'], img, frame_id, curtimename, shared_mem_file)
        total_inf = time.time() - start_inf

        detections = res["detections"]
        perf = {**perf, **res["perf"]}
        perf["imgencode"] = total_inf - perf["imgprep"] - perf["detection"]
        logging.info(f"perf: {perf}")

      # message the image capture upstream
      if curtimename is not None:
        messenger.send_image_and_detection(camId, curtimename, frame_id, detections)
        messenger.send_perf(camId, curtimename, frame_id, perf)
        logging.info(f"Notified of image upload: {cam['rtsp']} to {cam['space']}")

  # shutdown current video captures
  for key, cam in intervals_per_cam.items():
    cam['video'].stop()

def infer(detector, img, frame_id, img_name, shared_file = None):

  im = imutils.resize(img, width=400)
  if shared_file is not None:
    shared_file.seek(0)
    shared_file.write(im.tobytes())

    data = json.dumps({"frameId": frame_id, "image_name": img_name})
  else:  
    data = json.dumps({"frameId": frame_id, "image_name": img_name, "img": im.tolist()})
  
  headers = {'Content-Type': "application/json"}
  parameters = dict()
  
  if shared_file is not None:
    parameters["shared"] = shared_memory_name
    parameters["size"] = f'{im.shape[0]},{im.shape[1]},{im.shape[2]}'

  # wait for the detector to start
  for _ in range(24):
    try:
      resp = requests.post(detector, data, headers=headers, params = parameters)
      resp.raise_for_status()
      result = resp.json()

      return result
    except:
        time.sleep(10)
  
def report(messenger, cam, classes, scores, boxes, curtimename, proc_time):
  messenger.send_upload(cam, len(scores), curtimename, proc_time)
  time.sleep(0.01)
  messenger.send_inference(cam, classes, scores, boxes, curtimename)


def get_image_local_name(curtime):
  return os.path.abspath(curtime.strftime("%Y_%m_%d_%H_%M_%S_%f") + ".jpg")


def send_img_to_blob(blob_service_client, img, camId):

  curtime = datetime.datetime.utcnow()
  name = curtime.isoformat() + "Z"

  # used to write temporary local file
  # because that's how the SDK works.
  # the file name is used upload to blob
  local_name = get_image_local_name(curtime)
  day = curtime.strftime("%Y-%m-%d")

  blob_client = blob_service_client.get_blob_client("still-images", f"{camId}/{day}/{name}.jpg")
  cv2.imwrite(local_name, img)

  with open(local_name, "rb") as data:
    blob_client.upload_blob(data)

  os.remove(local_name)
  return name, f"{camId}/{day}"

if __name__ == "__main__":
    # remote debugging (running in the container will listen on port 5678)
    debug = False

    if debug:

        logging.info("Please attach a debugger to port 56780")

        import ptvsd
        ptvsd.enable_attach(('0.0.0.0', 56780))
        ptvsd.wait_for_attach()
        ptvsd.break_into_debugger()

    main()
