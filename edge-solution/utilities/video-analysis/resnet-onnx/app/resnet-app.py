# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

import threading
import cv2
import numpy as np
import io
import onnxruntime
import json

# Imports for the REST API
from flask import Flask, request, jsonify, Response

class ResnetModel:
    def __init__(self):
        self._lock = threading.Lock()

        with open('synset.txt', "r") as f:
            self._labelList = [l.rstrip() for l in f]

        #print(self._labelList)
        self._onnxSession = onnxruntime.InferenceSession('resnet50-v2-7.onnx')

    def Preprocess(self, cvImage):
        imageBlob = cv2.cvtColor(cvImage, cv2.COLOR_BGR2RGB)
        imageBlob = np.array(imageBlob, dtype='float32')
        imageBlob /= 255.
        imageBlob = np.transpose(imageBlob, [2, 0, 1])
        imageBlob = np.expand_dims(imageBlob, 0)

        return imageBlob

    def Postprocess(self, probabilities):
        sorted_prob = np.squeeze(np.sort(probabilities))[::-1]
        sorted_indices = np.squeeze(np.argsort(probabilities))[::-1]
        detectedObjects = []
             
        for i in range(3):
            confidence = sorted_prob[i]/100 #convert percent to decimal
            obj = self._labelList[sorted_indices[i]]
            obj_name = obj.split(' ', 1)[1]

            dobj = {
                "type" : "classification",
                "classification" : {
                    "tag" : {
                        "value" : obj_name, #skip the first word
                        "confidence" : confidence
                    }
                }
            }
            detectedObjects.append(dobj)

        return detectedObjects

    def Score(self, cvImage):
        with self._lock:

            imageBlob = self.Preprocess(cvImage)
            probabilities = self._onnxSession.run(None, {"data": imageBlob})
         
        return self.Postprocess(probabilities)


# global ml model class
resnet = ResnetModel()

app = Flask(__name__)

# / routes to the default function which returns 'Hello World'
@app.route('/', methods=['GET'])
def defaultPage():
    return Response(response='Hello World, from ResNet50v2 inferencing based on ONNX', status=200)

# /score routes to scoring function 
# This function returns a JSON object with inference duration and detected objects
@app.route('/score', methods=['POST'])
def score():
    global resnet
    try:
        # get request as byte stream
        reqBody = request.get_data(False)

        # convert from byte stream
        inMemFile = io.BytesIO(reqBody)

        # load a sample image
        inMemFile.seek(0)
        fileBytes = np.asarray(bytearray(inMemFile.read()), dtype=np.uint8)

        cvImage = cv2.imdecode(fileBytes, cv2.IMREAD_COLOR)

        # Infer Image
        detectedObjects = resnet.Score(cvImage)
 
        if len(detectedObjects) > 0:
            respBody = {                    
                        "inferences" : detectedObjects
                    }
            respBody = json.dumps(respBody)
            return Response(respBody, status= 200, mimetype ='application/json')
        else:
            return Response(status= 204)

    except:
        return Response(response='Error processing image', status=500)

if __name__ == '__main__':
    # Run the server
    app.run(host='0.0.0.0', port=8888)
