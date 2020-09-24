Your Virtual Azure Eye is a Mariner HCI image deployed as a VM into the Azure public cloud. This is the  same Mariner OS image as deployed in Azure Eye, however, in the public cloud it is Mariner compiled for the x86 instruction set, while for Azure Eye it is compiled for ARM64. Because it is the same image, the Virtual Eye has the same operational semantics as the Physical Eye.


You can directly access your Virtual Azure Eye in your subscription via SSH, however, by default the VM is not addressible on the open internet.  You must discover your local client IP address and then open a VNET rule for that IP address.  Once this happens you can freely SSH into your VM from that client.



![Eye VM](/images/NSG.png)


![Eye VM](/images/Allow-SSH.PNG)


![Eye VM](/images/Allow-SSH-Rule.PNG)


You can now SSH into your Virtual Eye in the same manner as if you were on the same local subnet as your physical Azure Eye.  Your image password is `p@ssw0rd`

![Eye VM](/images/SSH-Bash.PNG)

