# SSH Access to your Virtual Eye


Your Virtual Azure Eye is a Mariner HCI image deployed as a VM into the Azure public cloud. This is the  same Mariner OS image as deployed in Azure Eye, however, in the public cloud it is Mariner for Intel x86, while for Azure Eye it is compiled for ARM64. Because it is the same image with the same pre-installed components, the Virtual Eye has the same operational semantics as the Physical Eye.


You can directly access your Virtual Azure Eye in your subscription via SSH, however, by default the VM is not addressible on the open internet.  You must discover your local client IP address and then open a VNET rule for that IP address.  Once this happens you can SSH into your VM from your client device.  Here are the instructions to SSH into your Virtual Eye.


First, navigate to the `Resource Group Device` in your Azure Subscription from your original deployment. This is the Resource Group which hosts the Azure VM, VNET, etc. Click on the `default-NSG` resource:

![Eye VM](/images/NSG.png)

#

Next, click on the `AllowSSH` rule that was created as a part of the original deployment:

![Eye VM](/images/Allow-SSH.PNG)

#

Now you must enter your own client device public IP address into the network security rule. There are many sites which can provide this, such as http://checkip.dyndns.org/

Copy the public IP address of your local client device and place it into the `Source IP Address/CIDR Ranges` field of the `AllowSSH` security rule. This will allow your Virtual Eye VM to open SSH Port 22 from your client.  Press `Save` when done:

![Eye VM](/images/Allow-SSH-Rule.PNG)

#

You can now SSH into your Virtual Eye in the same manner as if you were on the same local subnet as your physical Azure Eye.  Your root password is `p@ssw0rd`, and you can see the list of IoT Edge containers running by executing the `iotedge list` command.  These are the same containers shown in your IoT Hub in the public cloud:

![Eye VM](/images/SSH-Bash.PNG)

