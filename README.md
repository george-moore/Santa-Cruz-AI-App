# Open Source People Detector AI Application


### Overview

This is an open source Santa Cruz AI application providing edge-based people detection. Video and AI output from the on-prem edge device is egressed to Azure Data Lake, with the user interface running as an Azure Website:

![](/media/People-Detector-AI.gif)

###
This application can execute against a fully emulated Santa Cruz AI Devkit in the cloud, or with a physical AI Devkit.

Press this button to deploy the people detector application to your Santa Cruz AI device:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://ms.portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Funifiededgescenarios.blob.core.windows.net%2Farm-template%2Fazuredeploy-updated.json)

**Please note: the current implementation runs as emulation in the cloud. A version for the physical Santa Cruz Devkit will be available soon.**
##
Software Emulation Topology
![](/media/Software-Emulation.PNG)
##
Physical Hardware Topology
![](/media/Hardware-Topology.PNG)

##
This reference open source application showcases best practices for security, privacy and compliance.  It is intended to be immediately useful for anyone to use, but 



It has the following conceptual topology:

![](/media/AI-App-Topology.PNG)



# Details

![](/media/Public-IP.png)


#
## Video Sample License
The sample video included in this open source AI application is licensed under:

[MEVA Dataset](http://mevadata.org/) Copyright Notice and Disclaimers: © 2019 Kitware Inc. and the Intelligence Advanced Research Projects Activity (IARPA). "Multiview Extended Video with Activities" (MEVA) dataset by Kitware Inc. and the Intelligence Advanced Research Projects Activity (IARPA) is licensed under a [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/). Full License available at https://mevadata.org/resources/MEVA-data-license.txt. Please see Disclaimer of Warranties under Section 5 of the License. For more information about MEVA, please see [mevadata.org](http://mevadata.org).
