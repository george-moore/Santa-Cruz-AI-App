# Open Source People Detector AI Application


### Overview

This is an open source Santa Cruz AI application providing edge-based people detection. Video and AI output from the on-prem edge device is egressed to Azure Data Lake, with the user interface running as an Azure Website:


<img src="https://github.com/george-moore/Santa-Cruz-AI-App/blob/master/media/People-Detector-AI.gif" width="800"/>

###
This application can execute against a fully emulated Santa Cruz AI Devkit in the cloud, or with a physical AI Devkit.

Press this button to deploy the people detector application to either the cloud or your Santa Cruz AI device:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://ms.portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Funifiededgescenarios.blob.core.windows.net%2Farm-template%2Fazuredeploy-updated.json)

**Please note: the current implementation runs as emulation in the cloud. A version for the physical Santa Cruz Devkit will be available soon.**
## Software emulation app topology
<img src="https://github.com/george-moore/Santa-Cruz-AI-App/blob/master/media/Software-Emulation.PNG" width="800"/>

## Physical hardware app topology
<img src="https://github.com/george-moore/Santa-Cruz-AI-App/blob/master/media/Hardware-Topology.PNG" width="800"/>


# Installation details
This reference open source application showcases best practices for AI security, privacy and compliance.  It is intended to be immediately useful for anyone to use with their Santa Cruz AI device. Deployment starts with this button:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://ms.portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Funifiededgescenarios.blob.core.windows.net%2Farm-template%2Fazuredeploy-updated.json)

This will redirect you to the Azure portal with this deployment page:

<img src="https://github.com/george-moore/Santa-Cruz-AI-App/blob/master/media/Custom-Deployment.PNG" width="550"/>

You will need Owner or Contributor access to the subscription you select. To deploy an emulation environment in the cloud, please enter the following parameters:

* __Resource Group IoT__ = Unique name of a new resource group to host your IoT Hub, Data Lake and Web App
* __Resource Group Device__ = Unique name of a new resource group to host the virtualized Santa Cruz AI device. This virtualized device connects to your Data Lake to store the AI and Video output.
* __Device Architecture__ = X86 - Only x86-based devices is supported at this time. ARM64 is coming soon!
* __Module Runtime__ = CPU - Only CPU-based AI inferencing in emulation is supported at this time. Movidius Myriad X is coming soon!
* __Password__ = a password to protect access to the web app which visualizes your output. A best practice is to assign a password to prevent others on the internet from seeing the testing output of your Santa Cruz AI device.

Once deployment is complete, you can launch the web application by navigating to the *Resource Group IoT* name selected above. You will see an Azure Web Services deployment which starts with "ues-eyeapp" followed by 4 random digits. Select this app, then chose the "Browse" button in the top left. You will need to supply the password you entered at deployment time to access the application.

It has the following conceptual topology:

![](/media/AI-App-Topology.PNG)



