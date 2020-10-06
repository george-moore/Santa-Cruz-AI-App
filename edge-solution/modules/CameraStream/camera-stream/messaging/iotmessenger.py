
# pylint: disable=E0611
from azure.iot.device import IoTHubModuleClient, Message

import logging
import json

logging.basicConfig(format='%(asctime)s  %(levelname)-10s %(message)s', datefmt="%Y-%m-%d-%H-%M-%S",
                    level=logging.INFO)

class IoTMessaging:
  timeout = 10000

  def __init__(self):
    self.client = IoTHubModuleClient.create_from_edge_environment()

    # set the time until a message times out
    self.output_queue = "iotHub"

  def send_event(self, body, msg_type="message"):

    message = Message(json.dumps(body))
    message.custom_properties["type"] = msg_type
    self.client.send_message(message)

class IoTInferenceMessenger(IoTMessaging):
  def __init__(self):
    super().__init__()
    self.context = 0

  def send_inference(self, camId, classes, scores, bboxes, curtimename):

    if self.client is None or classes == []:
        return

    for classs, score, bbox in zip(classes, scores, bboxes):
        body = {"cameraId": camId, "time": curtimename,
                "cls": classs, "score": score}
        body["bbymin"] = bbox[0]
        body["bbxmin"] = bbox[1]
        body["bbymax"] = bbox[2]
        body["bbxmax"] = bbox[3]

        self.send_event(body)
        logging.info(f"Sent: {body}")

  def send_upload(self, camId, featureCount, curtimename, proc_time):
      body = {"cameraId": camId, "time": curtimename,
              "procMsec": proc_time * 1000, "type": "jpg", "procType": "CPU"}
      body["featureCount"] = featureCount

      self.send_event(body)
      logging.info(f"Sent: {body}")

  def send_image_and_detection(self, camId, imgname, frame_id, detections):
      body = {"cameraId": camId, "image_name": imgname, "frameId": frame_id, "detections": detections}

      self.send_event(body, "image")
      logging.info(f"Sent image: {imgname}")

  def send_perf(self, camId, imgname, frame_id, perf):
      body = {"cameraId": camId, "image_name": imgname, "frameId": frame_id, "perf": perf}

      self.send_event(body, "perf")
