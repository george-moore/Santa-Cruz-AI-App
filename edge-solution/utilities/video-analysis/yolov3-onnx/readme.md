# Yolov3 ONNX model

The following instructions will enable you to build a Docker container with [Yolov3](http://pjreddie.com/darknet/yolo/) [ONNX](http://onnx.ai/) model using [nginx](https://www.nginx.com/), [gunicorn](https://gunicorn.org/), [flask](https://github.com/pallets/flask), [runit](http://smarden.org/runit/), and [pillow](https://pillow.readthedocs.io/en/stable/index.html).

Note: References to third-party software in this repo are for informational and convenience purposes only. Microsoft does not endorse nor provide rights for the third-party software. For more information on third-party software please see the links provided above.

## Contributions needed

* Improved logging
* Graceful shutdown of nginx and gunicorn

## Prerequisites

1. [Install Docker](http://docs.docker.com/docker-for-windows/install/) on your machine
2. Install [curl](http://curl.haxx.se/)

## Building the docker container

Build the container image (should take some minutes) by running the following Docker command from a command window in that directory

```bash
    docker build . -t yolov3-onnx:latest
```

## Running and testing

Run the container using the following Docker command

```bash
    docker run  --name my_yolo_container -p 8080:80 -d  -i yolov3-onnx:latest
```

Note that you can use any host port that is available instead of 8080.

Test the container using the following commands

### /score

To get a list of detected objects using the following command

```bash
   curl -X POST http://127.0.0.1:8080/score -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg>
```

If successful, you will see JSON printed on your screen that looks something like this

```JSON
{
    "inferences": [
        {
            "entity": {
                "box": {
                    "h": 0.3498992351271351,
                    "l": 0.027884870008988812,
                    "t": 0.6497463818662655,
                    "w": 0.212033897746693
                },
                "tag": {
                    "confidence": 0.9857677221298218,
                    "value": "person"
                }
            },
            "type": "entity"
        },
        {
            "entity": {
                "box": {
                    "h": 0.3593513820482337,
                    "l": 0.6868949751420454,
                    "t": 0.6334065123374417,
                    "w": 0.26539528586647726
                },
                "tag": {
                    "confidence": 0.9851594567298889,
                    "value": "person"
                }
            },
            "type": "entity"
        }
    ]
}
```

#### Filter objects of interest

To filter the list of detected objects use the following command

```bash
   curl -X POST "http://127.0.0.1:8080/score?object=<objectType>" -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg>
```

The above command will only return objects of objectType

#### Filter objects of interest above a confidence threshold

To filter the list of detected objects above a certain confidence threshold use the following command

```bash
   curl -X POST "http://127.0.0.1:8080/score?object=<objectType>&confidence=<confidenceThreshold>" -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg>
```

In the above command, confidenceThreshold should be specified as a float value.

#### View video stream with inferencing overlays

You can use the container to process video and view the output video with inferencing overlays in a browser. To do so, you can post video frames to the container with stream=<stream-id> as a query parameter (i.e. you will need to post video frames to [http://127.0.0.1:8080/score?stream=teststream](http://127.0.0.1/score?stream=teststream). The output video can then be viewed by going to [http://127.0.0.1:8080/stream/test-stream](http://127.0.0.1:8080/stream/teststream).

### /annotate

To see the bounding boxes overlaid on the image run the following command

```bash
   curl -X POST http://127.0.0.1:8080/annotate -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg> --output out.jpeg
```

If successful, you will see a file out.jpeg with bounding boxes overlaid on the input image.

### /score-debug

To get the list of detected objects and also generate an annotated image run the following command

```bash
   curl -X POST http://127.0.0.1:8080/score-debug -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg>
```

If successful, you will see a list of detected objected in JSON. The annotated image will be generated in the /app/images directory inside the container. You can copy the images out to your host machine by using the following command

```bash
   docker cp my_yolo_container:/app/images ./
```

The entire /images folder will be copied to ./images on your host machine. Image files have the following format dd_mm_yyyy_HH_MM_SS.jpeg

## Terminating

Terminate the container using the following docker commands

```bash
docker stop my_yolo_container
docker rm my_yolo_container
```

## Upload docker image to Azure container registry

Follow instruction in [Push and Pull Docker images  - Azure Container Registry](http://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli) to save your image for later use on another machine.

## Deploy as an Azure IoT Edge module

Follow instruction in [Deploy module from Azure portal](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-deploy-modules-portal) to deploy the container image as an IoT Edge module (use the IoT Edge module option).
