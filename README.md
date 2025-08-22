# Xen-Orchestra (Community Edition) Installer

Xen-Orchestra (Community Edition) allows you to administer Citrix Hypervisor (aka XenServer) and XCP-ng as well as backup any VM's running on these systems. The single line installation script allows you to go from a bare-minimal installation of [Ubuntu](https://ubuntu.com/download/server) or [Debian (Server)](https://www.debian.org/distrib/netinst) to fully operational XOCE server.

## System Minimum Requirements for installation

* 1 vCPU
* 3 GiB RAM
* 10 GiB disk space

## System recommendations for operation

* 2 vCPU recommended 
* 3 GiB of RAM (for environments containing 500+ VMs increase the amount RAM)
* 20 GiB disk space (for system updates)

## Assumptions

* We assume you have a Virtual or physical server running a currently supported Ubuntu or Debian server installation with internet connectivity
* You've read this community and understand what installation entails and does on your soon to be XOCE server

## Installation
 
Run the following steps from a root shell on your **Ubuntu or Debian** host.

	sudo bash
	bash -c "$(curl https://raw.githubusercontent.com/Jarli01/xenorchestra_installer/master/xo_install.sh)"
    
The default username and password are applied, admin@admin.net and admin for the password

If you don't want NFS capabilities run ```sudo apt-get remove nfs-common```.

* Do not use LAMP
* SSH Access is optional, but highly recommended

## Updates

To maintain your installation from Source or from this repo. (either prepackaged or scripted installation) we recommend using the update script which this community maintains. This can be [found here](https://github.com/Jarli01/xenorchestra_updater) and doesn't require you to download or install a separate package to your XOCE installation. Simply run it via shell session of your XOCE host.

# Declarations

This script automates the manual process which can be [found here](https://docs.xen-orchestra.com/installation) as well as removes a few feature restrictions that otherwise would need to be changed manually if following the manual installation process. This script is not officially supported by the Vates team, but is supported by this community. 

# Self-signed SSL 

If you are running this internally and need SSL (recommended) follow the below steps to create a self-signed SSL key and certificate; while browsers will still say the connection is unsecured, this is because the certificate isn't from a public authority and is on your LAN. You can add this cert to your systems root authority if it want to to remove the warning. Alternatively a reverse proxy can be used for public facing installations.  

## Generate your key and cert from your XOCE installation

    sudo openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout /etc/ssl/private/key.pem -out /etc/ssl/certs/certificate.pem
    
Now edit the xo-server.toml file

    vi /opt/xen-orchestra/packages/xo-server/.xo-server.toml
    
Comment-out or edit the port from 80 to 443 and add the cert and key to the appropriate locations within this file.
    
    port = 443
    cert = '/etc/ssl/certs/certificate.pem'
    key = '/etc/ssl/private/key.pem'
    
Restart xo-server.service

    systemctl restart xo-server.service

Reload your XOCE website using SSL (https://your-host-ip)

# Migrating from VMWare ESXi
For a legal reasons we cannot provide an automated solution to installing these dependencies which offer increased performance and features while migrating VMs from VMWare ESXi. These steps do not need to be followed for every instance, but are recommended if you're migrating away. 

1. Go to https://developer.broadcom.com/sdks/vmware-virtual-disk-development-kit-vddk/latest and download the VDDK #.0 Tarball for Linux (at writing the version is 9.0 and MD5 sum is f508fe7134fcdd137fbdba5ee7f65d9f) 
2. Move this file to your XOCE installation (winSCP or some other tool)
3. Create this directory as it doesn't exist `/usr/local/lib/vddk` and uncompress the tarball into the same directory with ```sudo tar -xvf "./VMware-vix-disklib-9.0.0.0.24742305.x86_64.tar.gz" -C /usr/local/lib/vddk```

   The directory structure should look match the below
 
```  
debian@xoa-source:/usr/local/lib/vddk$ tree -d .
└── vmware-vix-disklib-distrib
    ├── bin64
    ├── doc
    │   ├── errors
    │   ├── functions
    │   ├── samples
    │   │   └── diskLib
    │   └── types
    ├── include
    ├── lib32
    └── lib64
```
4. Lastly install these dependencies ```sudo apt install -y nbdkit libnbd-bin```
5. You should now have access to the improved features from this VDDK

# Problems?

Check out our [Troubleshooting Page](https://github.com/Jarli01/xenorchestra_installer/blob/master/TROUBLESHOOTING.md)!

# Goals/Backstory for this script

I'm often asked "why can't this be run on CentOS or Fedora" to which my only reply is and has ever been: The goal was to be the XCP-ng of XS. Which means I wanted a solution that offered as much as XOA offers, while using what is available freely and from open sources. Without restrictions. 

That isn't to say that this installation script won't work on other distributions, please contribute and help us to spread XOCE to other platforms. 

Initially my goal was to simply setup and start using XOCE for a tiny production shop to be able to use an open source hypervisor (Citrix XenServer at the time) and have a management tool/backup solution. Which was initially [NAUBackup](https://github.com/NAUbackup/VmBackup) and XenCenter, when I found XOA and that there was an open source management solution and backup solution that wasn't script based I jumped for it, taking the manual installation process provided by Olivier and his team and automating it. 

That goal transformed into the desire to assist the developers of XOA by using and hopefully finding any bugs or quirks that needed to be worked out while staying in line with the original goal of being as nearly compatibile as possible to XOA.

While the goal initially was to have a solution as close to XOA as possible, with the script came the ability and goal to automate the installation. This is a big deal for these scripts today, while providing an as near-match solution to XOA as possible. 

To keep XOCE up to date I recommend that anyone who's used this installation script or the sources installation to use this: https://github.com/Jarli01/xenorchestra_updater

## Adding XOCE v6 to your installation (this is a Work In Progress by Vates)

	cd /opt/xen-orchestra
	yarn run turbo run build --filter @xen-orchestra/web

Once the installation is completed, you can then go to [https://your-host-ip/v6](https://your-host-ip/v6)
