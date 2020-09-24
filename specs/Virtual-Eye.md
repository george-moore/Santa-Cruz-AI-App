Your Virtual Azure Eye is a Mariner HCI image deployed as a VM into the Azure public cloud. This is the  same Mariner OS image as deployed in Azure Eye, however, in the public cloud it is Mariner for Intel x86, while for Azure Eye it is compiled for ARM64. Because it is the same image with the same pre-installed components, the Virtual Eye has the same operational semantics as the Physical Eye.


You can directly access your Virtual Azure Eye in your subscription via SSH, however, by default the VM is not addressible on the open internet.  You must discover your local client IP address and then open a VNET rule for that IP address.  Once this happens you can freely SSH into your VM from that client.



![Eye VM](/images/NSG.png)


![Eye VM](/images/Allow-SSH.PNG)


![Eye VM](/images/Allow-SSH-Rule.PNG)


You can now SSH into your Virtual Eye in the same manner as if you were on the same local subnet as your physical Azure Eye.  Your root password is `p@ssw0rd`, and you can see the list of IoT Edge containers running by executing the `iotedge list` command.  These are the same containers shown in your IoT Hub in the public cloud:

![Eye VM](/images/SSH-Bash.PNG)

