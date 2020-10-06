import numpy as np
import cv2

CLASSES = ["background", "aeroplane", "bicycle", "bird", "boat",
            "bottle", "bus", "car", "cat", "chair", "cow", "diningtable",
            "dog", "horse", "motorbike", "person", "pottedplant", "sheep",
            "sofa", "train", "tvmonitor"]

COLORS = np.random.uniform(0, 255, size=(len(CLASSES), 3))

def display(frame, detections):	

  (h, w) = frame.shape[:2]

  for detection in detections:
    # draw the prediction on the frame
    label = "{}: {:.2f}".format(detection["label"], detection["confidence"])
    startX, startY, endX, endY = (np.array(detection["bbox"]) * np.array([w, h, w, h])).astype("int")
    idx = detection["class"]

    cv2.rectangle(frame, (startX, startY), (endX, endY),
      COLORS[idx], 2)
    y = startY - 15 if startY - 15 > 15 else startY + 15
    cv2.putText(frame, label, (startX, y),
      cv2.FONT_HERSHEY_SIMPLEX, 0.5, COLORS[idx], 2)

  return frame

def format_detections(startX, startY, endX, endY, label_idx, confidence):
  return {"bbox": [float(startX), float(startY), float(endX), float(endY)], "label": CLASSES[label_idx], "confidence": float(confidence), "class": label_idx }