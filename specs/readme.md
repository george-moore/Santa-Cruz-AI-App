This reference application hosts an open source SSD-MobileNet based AI model which has been trained in people detection using the Microsoft COCO dataset: https://cocodataset.org/

It has the following overall topology consisting of two primary Azure IoT Edge containers running within the Santa Cruz device, connected to several Azure cloud components:

![](/images/AI-App-Topology.PNG)

You can view the details on these two containers by visting the IoT Hub which was deployed as a part of this application.  Choose **IoT Edge** in the left rail under **Automatic Device Management**.  Once selected, you'll see your **azureEyeEdgeDevice** in the main portal window:

![](/images/IoT-Hub-Edge.png)
#
Once you click on the **azureEyeEdgeDevice**,  you will see this page:

![](/images/IoT-Hub-Containers.png)
#

![](/images/IoT-Hub-Identity-Twin.png)
#

![](/images/IoT-Hub-Identity-Twin-Details.png)
#
