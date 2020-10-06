# Yolov3 ONNX model for encryption through the wire I/O (TLS).

*An alternative for scenarios where the YOLO inferencing container, will run separately from IoT Edge (i.e. you have a spare beefy (hardware capable) server you'd like to use for this intensive task; given the amount of cameras you'll be feeding LVA with, which in turn, will demand simultaneous inferencing from this container). Although possible from a technical standpoint, if the inferencing container will run under IoT Edge's umbrella, a TLS certificate won't bring any added value. In this case, our suggestion is to walk the [regular documented path](../yolov3-onnx/readme.md)*

The following instruction will enable you to build a docker container with [Yolov3](http://pjreddie.com/darknet/yolo/) [ONNX](http://onnx.ai/) model using [nginx](https://www.nginx.com/), [gunicorn](https://gunicorn.org/), [flask](https://github.com/pallets/flask), and [runit](http://smarden.org/runit/). The container exposes port 443 to the outside world.

> Note that the SSL connection alone won't discriminate clients, allowing port access to services other than LVA. Mechanisms like username/password or http headers would help if necessary.

We'll show two ways to deal with SSL certificates; BYO Certificate and Self Signed Certificate.

Note: References to third-party software in this repo are for informational and convenience purposes only. Microsoft does not endorse nor provide rights for the third-party software. For more information on third-party software please see the links provided above.

## Contributions needed

* Improved logging
* Graceful shutdown of nginx and gunicorn

## Prerequisites

1. [Install Docker](http://docs.docker.com/docker-for-windows/install/) on your machine
2. Install [curl](http://curl.haxx.se/)

## BYO certificate

### Involving the IT team in the process
It's really important to involve the right areas here. The organization you're working for, might have it's own policies in place to deal with SSL certificates related issues, such as: naming, providers, TTL (time to live), among other not/technical ones.

### Dropping certificate files for docker container to pick them up

First, create a `certs` directory where you'll copy the certificate files to. This directory will be mounted to the container, where the nginx config file expects it (more on this right after).

On the Host computer, run: `sudo mkdir /certs`

Copy the public and private key pair files to the newly created directory. Note that our sample uses .pem files which is the format recommended by LVA. Other formats can be used as well, provided the ignoreSignature property is true or that the certificate has been signed by a well-known CA.

Reading material:

* https://nginx.org/en/docs/http/configuring_https_servers.html#chains
* https://serverfault.com/a/9717

### Updating Nginx server config file

Set the right names for the certificate files, to match what you've copied to the `/certs` folder at Host computer level. The file you need to update is [yolov3-app.conf](yolov3-app.conf)

### Building, publishing and running the docker container

Please update the contents for the nginx configuration file `yolo3-app.conf`.
```
    # Public
    ssl_certificate /certs/<file-name>.pem;
    # Private
    ssl_certificate_key /certs/<file-name>-key.pem;
```

After getting a certificate, copying its pieces and updating the nginx configuration file, you're ready to begin the image building process.

To build the image, use the docker file named `Dockerfile`.

First, a couple assumptions

* We'll be using Azure Container Registry (ACR) to publish our image before distributing it
* Our local docker is already loged into ACR.
* Our hypothetical ACR name is "myregistry". Your may defer, so please update it properly along the following commands.

> If you're unfamiliar with ACR or have any questions, please follow this [demo on building and pushing an image into ACR](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli).

`cd` onto the repo's root directory
```
sudo docker build --pull --rm -f "utilities/video-analysis/tls-yolov3-onnx/Dockerfile" -t secureyolov3:latest "utilities/video-analysis/tls-yolov3-onnx"

sudo docker tag secureyolov3:latest myregistry.azurecr.io/secureyolov3:1

sudo docker push myregistry.azurecr.io/secureyolov3:1
```

Then, from the box where the container should execute, run this command:

`sudo docker run -d -p 443:443 --name tls-yolov3 --mount type=bind,source=/certs,target=/certs myregistry.azurecr.io/secureyolov3:1`

Let's decompose it a bit:

* `-p 443:443`: it's up to you where you'd like to map the containers 443 port. You can pick whatever port fits your needs.
* `--mount`: here the Host directory where we dropped the certificate files earlier, is bound into the container, so the image able to consume them.
* `registry/image:tag`: replace this with the corresponding location/image:tag where you've pushed the image built from the `Dockerfile`

### Updating references into Topologies, to target the HTTPS inferencing container address
The topology (i.e. https://github.com/Azure/live-video-analytics/blob/master/MediaGraph/topologies/evr-hubMessage-assets/topology.json) must define a YOLO inferencing:

* Url Parameter
```
      {
        "name": "inferencingUrl",
        "type": "String",
        "description": "inferencing Url",
        "default": "https://<REPLACE-WITH-IP-NAME>/score"
      },
```
* Configuration
```
{
	"@apiVersion": "1.0",
	"name": "TopologyName",
	"properties": {
    "processors": [
      {
        "@type": "#Microsoft.Media.MediaGraphHttpExtension",
        "name": "inferenceClient",
        "endpoint": {
          "@type": "#Microsoft.Media.MediaGraphTlsEndpoint",
          "url": "${inferencingUrl}",
          "credentials": {
            "@type": "#Microsoft.Media.MediaGraphUsernamePasswordCredentials",
            "username": "${inferencingUserName}",
            "password": "${inferencingPassword}"
          }
        },
        "image": {
          "scale":
          {
            "mode": "Pad",
            "width": "416",
            "height": "416"
          },
          "format":
          {
            "@type": "#Microsoft.Media.MediaGraphImageFormatEncoded",
            "encoding": "jpeg",
            "quality": "90"
          }
        }
      }
    ]
  }
}
```

## The Self-Signed certificate way
Shorter, yes. Use it wisely and consider that real-world production scenarios, may require a valid CA issued certificate instead.

### Find out the network reachable IP address or Server's name
With that data, head to the [Dockerfile (for Self-Signed)](Dockerfile.ss), and replace where's indicated.

### Building, publishing and running the docker container
To build the image, use the docker file named `Dockerfile.ss`.

First, a couple assumptions

* We'll be using Azure Container Registry (ACR) to publish our image before distributing it
* Our local docker is already loged into ACR.
* Our hypothetical ACR name is "myregistry". Your may defer, so please update it properly along the following commands.

> If you're unfamiliar with ACR or have any questions, please follow this [demo on building and pushing an image into ACR](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli).

`cd` onto the repo's root directory
```
sudo docker build --pull --rm -f "utilities/video-analysis/tls-yolov3-onnx/Dockerfile.ss" -t tlsssyolov3:latest "utilities/video-analysis/tls-yolov3-onnx"

sudo docker tag tlsssyolov3:latest myregistry.azurecr.io/tlsssyolov3:1

sudo docker push myregistry.azurecr.io/tlsssyolov3:1
```

Then, from the box where the container should execute, run this command:

`sudo docker run -d -p 443:443 --name tls-yolov3 myregistry.azurecr.io/tlsssyolov3:1`

### Updating references into Topologies, to target the HTTPS inferencing container address
The topology must define a YOLO inferencing:

* Url Parameter
```
      {
        "name": "inferencingUrl",
        "type": "String",
        "description": "inferencing Url",
        "default": "https://<REPLACE-WITH-IP-NAME>/score"
      },
```
* Configuration
```
{
	"@apiVersion": "1.0",
	"name": "TopologyName",
	"properties": {
    "processors": [
      {
        "@type": "#Microsoft.Media.MediaGraphHttpExtension",
        "name": "inferenceClient",
        "endpoint": {
          "@type": "#Microsoft.Media.MediaGraphTlsEndpoint",
          "url": "${inferencingUrl}",
          "credentials": {
            "@type": "#Microsoft.Media.MediaGraphUsernamePasswordCredentials",
            "username": "${inferencingUserName}",
            "password": "${inferencingPassword}"
          },
          "validationOptions": {
            "ignoreHostname": "true",
            "ignoreSignature": "true"
          }
        },
        "image": {
          "scale":
          {
            "mode": "Pad",
            "width": "416",
            "height": "416"
          },
          "format":
          {
            "@type": "#Microsoft.Media.MediaGraphImageFormatEncoded",
            "encoding": "jpeg",
            "quality": "90"
          }
        }
      }
    ]
  }
}
```
> [!NOTE]  
> "validationOptions": here we configure that for this particular endpoint, no Issuer signature validation will occur. This mechanism allows the self signed Certificate to bypass authentication. Without it, the SSL connection would be rejected by LVA because the certificate is not trusted.

## Using the yolov3 container

Test the container using the following commands

### /score

To get a list of detected objected using the following command

```bash
   curl -X POST https://<REPLACE-WITH-IP-OR-NAME>/score -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg>
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

Terminate the container using the following docker commands

```bash
docker stop tls-yolov3
docker rm tls-yolov3
```

### /annotate

To see the bounding boxes overlaid on the image run the following command

```bash
   curl -X POST https://<REPLACE-WITH-IP-OR-NAME>/annotate -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg> --output out.jpeg
```

If successful, you will see a file out.jpeg with bounding boxes overlaid on the input image.

### /score-debug

To get the list of detected objects and also generate an annotated image run the following command

```bash
   curl -X POST https://<REPLACE-WITH-IP-OR-NAME>/score-debug -H "Content-Type: image/jpeg" --data-binary @<image_file_in_jpeg>
```

If successful, you will see a list of detected objected in JSON. The annotated image will be genereated in the /app/images directory inside the container. You can copy the images out to your host machine by using the following command

```bash
   docker cp tls-yolov3:/app/images ./
```

The entire /images folder will be copied to ./images on your host machine. Image files have the following format dd_mm_yyyy_HH_MM_SS.jpeg

## Upload docker image to Azure container registry

Follow instruction in [Push and Pull Docker images  - Azure Container Registry](http://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli) to save your image for later use on another machine.

## Deploy as an Azure IoT Edge module

Follow instruction in [Deploy module from Azure portal](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-deploy-modules-portal) to deploy the container image as an IoT Edge module (use the IoT Edge module option).
