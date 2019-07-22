# alarm
Linux based fast response system relying on Amazon Dash buttons

What you need
=============
- Amazon Dash buttons to trigger the alarms
- Smartphone with Amazon App in order to register the Dash buttons
- TP-Link WR1043v5 wireless router, or any other version of you want to buidl the image by yourself
- Linux clients for displaying the alarms, Debian bases distributions if you want to install the binary package

Installation
============
1. TP-Link WR1043
- Download and flash the OpenWRT image provided here or 
- Download the files/ and packages/ directories to your imagbuilder directory: openwrt-imagebuilder-18.06.1-ar71xx-generic.Linux-x86_64, build and flash the iamge to the TP-Link WR1043v5
- Configure the wireless router router in order to provide a wifi network and have direct access to your WAN and LAN; choose a new SSID for your wifi (it should only be accessed by the Dash buttons and the admin)
- Connect your smartphone with the new wifi and register the Dash buttons; stop before choosing a product. 
- When you are finished, reconfigure the TP-Link as Access Point behind your actual router and make sure thet the TP-Link is banned by the proper router from accesing the internet (so Amazon is now out of the game). Do not rename the wifi though!
- Configure the Access Point (see "Configuration"): ssh to the TP-Link and edit /etc/alarm/alarm_ap.conf

2. CENTRAL
One of the clients has to serve as a central distributor. This client should be in the LAN all the time ar at least be the most reliable node in your LAN. We simply call it CENTRAL here.
- Install alarm-central_XXX_all.deb:
<pre>dpkg -i alarm-central_XXX_all.deb || apt-get install -f</pre>
- Execute as root:
<pre>alarm-central-postinstallation.sh</pre>
- Set a password for the user alarm on CENTRAL, so clients can later transfer their ssh keys to CENTRAL.
- Start and enable alarmd as daemon on CENTRAL.
- Transfer the AP ssh key to CENTRAL: log into the AP and execute /usr/bin/alarm_copy_ap_key.sh

3. Clients
Clients are the nodes reacting visually and acoustically to alarms. If CENTRAL should do so also, install additionally the client package in CENTRAL.
- Install alarm-client_XXX_all.deb:
<pre>dpkg -i alarm-client_XXX_all.deb || apt-get install -f</pre>
- Execute as root:
<pre>alarm-postinstallation.sh</pre>

Configuration
=============
