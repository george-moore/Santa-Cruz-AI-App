
#### Install Package Dependencies

The following installation steps use apt package manager and are tested on Ubuntu 18.04 LTS.  
If your machine uses a different package manager, please update the commands to use that package manager instead of apt.

1. Install jq, sshpass, curl, python-pip timeout wget packages using your package manager.
	
	The following commands use apt package manager in Ubuntu. 
	```sh
	 sudo apt update
	 sudo apt install -y curl jq sshpass python-pip timeout wget
	 ```

1. Install Docker and restart your machine for it to take effect
	
	```sh
	curl -fsSL https://get.docker.com -o get-docker.sh
	sh get-docker.sh
	sudo usermod -aG docker $USER
	```

1. Install Azure CLI
	
	```
	curl -L https://aka.ms/InstallAzureCli | bash
	```

1. Install Azure IoT Extension
	
	```
	az extension add --name azure-iot
	```

1. Install iotedgedev utility
	
	```
	pip install docker-compose
	pip install iotedgedev
	```

	You may need to run the below commands to allow your system to find iotedgedev
	```
	echo "PATH=~/.local/bin:$PATH" >> ~/.bashrc
	source ~/.bashrc
	```

	Test iotedgedev installation by running the below command
	```
	iotedgedev --version
	```
1. Install AzCopy

	Download AzCopy for linux from [here](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10#download-azcopy)

	Unzip the downloaded AzCopy gzip file

	Copy the azcopy executable from unzipped directory to /user/bin so it's available for use in the system

	```
	sudo cp ./azcopy_linux_amd64_*/azcopy /usr/bin/
	```
