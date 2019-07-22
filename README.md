# alarm
Linux based fast response system relying on Amazon Dash buttons

What you need
-------------
- Amazon Dash buttons to trigger the alarms
- Smartphone with Amazon App in order to register the Dash buttons
- TP-Link WR1043v5 wireless router, or any other version of you want to buidl the image by yourself
- Linux clients for displaying the alarms, Debian bases distributions if you want to install the binary package

Installation
------------
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

1. AP
The configuration file is located in /etc/alarm/alarm_ap.conf. 
* ALARM_NETWORK: the first three octets of your lan; sorry, no other subnet masks supported at this time. End with a dot.
* ALARM_MAC: identify the mac addresses of your Dash buttons with a human readable name, e.g. the brand name of the button. The identification with a location occurs later when configuring CENTRAL.
* ALARM_TARGETS: list of last octet of the local IP of the alarm clients, including CENTRAL, but excluding AP.

2. CENTRAL
- /etc/alarm/alarm_global_central.conf
Contains default definitions to be distributed to all clients. The buttons are identified by the names given in ALARM_MAC if
the AP config file. The most important definitions here are
    - ALARM['DESCRIPTION','<buttonname>']: This should be the location of the Dash button when being pressed. This description is being displayed in the visual alarm.
    - ALARM['AUDIO','<buttonname>']: The name of the audio file in /usr/share/alarm/audio/ being used for the alarm
    - ALARM['AUDIO_VOLUME','<buttonname>']: ranges from 1 to 3
    - ALARM['VIDEO','<buttonname>']: "fullscreen", "normal" or "" 
    - ALARM['IP','<buttonname>']: IP addresses of clients in the room of the Dash button. If the alarm is triggered, these clients will not react to the alarm and instead be able to give the all-clear signal on the triggered alarm. If you want to separate these features, do noet set 'IP' but:
    - ALARM['NOALARM','<buttonname>']: IP addresses of clients which should not react to the alarm.
    - ALARM['ALLCLEAR','<buttonname>']: IP addresses of clients which are permitted to give the all-clear on the alarm.

The settings on 'Default' insted of '<buttonname>' apply to all buttons. Changes on individual buttons should be stated in the last paragraph of the config file.
  
 3. Clients
 - /etc/alarm/alarm_local.conf
You can edit this local config file in largely the same way as described for the global config file on CENTRAL. However, you can also use a graphical tool.
 - The graphical tool
Browse to System/Control Center/Personal/Alarm Notification Configurator and use the tool. You can edit the behaviour of the Default or any individual button permanently on the client or for just this session; after the next reboot, the session settings are reset.
