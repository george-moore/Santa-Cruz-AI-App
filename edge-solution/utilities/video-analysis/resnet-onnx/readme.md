# ResNet ONNX Model

The following instructions will enable you to build a Docker container with a [ResNet](https://github.com/onnx/models/blob/master/vision/classification/resnet/README.md) [ONNX](http://onnx.ai/) model using ResNet50 v2.

## Prerequisites
1. [Install Docker](http://docs.docker.com/docker-for-windows/install/) on your machine
2. Install [curl](http://curl.haxx.se/)

## Building the Docker Container
Build the container image by running the following Docker command. Make sure you are in the same directory as the Dockerfile. This step may take a few minutes.

```bash
docker build . -t resnet50v2-onnx:latest
```
    
## Running and Testing
The REST endpoint for ResNet accepts an image with the size of 224 pixels by 224 pixels, which is required by the ResNet model. Since LVA Edge is capable of sending specifically sized images in specific formats, we are not preprocessing the incoming images to resize them. This is mainly done for performance improvements. Thus, to run the commands below, you must use images that are 224x224.

Run the container using the following Docker command

```bash
docker run  --name my_resnet50v2_container -p 8080:80 -d  -i resnet50v2-onnx:latest
```

Test the container using the following commands

### /score
To get a list of detected objected, use the following command

```bash
curl -X POST http://127.0.0.1:8080/score -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg>
```
If successful, you will see JSON printed on your screen that looks something like this
```json
{
    "inferences": [
        {
            "type": "classification",
            "classification": {
                "tag": {
                    "value": "llama",
                    "confidence": 0.1784792137145996
                }
            }
        },
        {
            "type": "classification",
            "classification": {
                "tag": {
                    "value": "gazelle",
                    "confidence": 0.11214914321899414
                }
            }
        },
        {
            "type": "classification",
            "classification": {
                "tag": {
                    "value": "wallaby, brush kangaroo",
                    "confidence": 0.10473043441772462
                }
            }
        }
    ]
}
```

Terminate the container using the following Docker commands

```bash
docker stop my_resnet50v2_container
docker rm my_resnet50v2_container
```

## Upload docker image to Azure container registry

Follow the instruction in [Push and Pull Docker images - Azure Container Registry](http://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli) to save your image for later use on another machine.

## Deploy as an Azure IoT Edge module

Follow the instructions in [Deploy module from Azure portal](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-deploy-modules-portal) to deploy the container image as an IoT Edge module (using the IoT Edge module option). 

