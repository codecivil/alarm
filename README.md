# alarm
Linux based fast response system relying on myStrom buttons

What you need
-------------
- myStrom simple wifi buttons to trigger the alarms (there is no adapted firmware for the plus buttons yet)
- TP-Link WR1043v2 wireless router, or any other version of you want to build the image by yourself
- Linux clients for displaying the alarms, Debian based distributions if you want to install the binary package

Installation
------------
1. TP-Link WR1043

	- Download and flash the appropriate OpenWRT image provided in res/ OR 
	- Download the tl-wr0143nd-v2 directory contents parallel to your imagebuilder directory: openwrt-imagebuilder-21.02.3-ath79-generic.Linux-x86_64, build the image with myMake-v5.sh and flash it to the TP-Link WR1043v5
	- Connect the AP to your LAN (preferably by cable)
	- Create an interface ALARM
	- Connect it to a wlan (<ALARM-WLANNAME> for later reference), but disconnect from everything else (no lan or internet over this WLAN!)
	- activate MAC filter
	- set WLAN password, since some/our buttons do not connect to open WLANs!
	- deactivate DHCP (connections should not succeed..., but still may); only
	activate for button integration (s. below)
	- Configure and register the myStrom buttons (see 2., below)
	- When you are finished, reconfigure the TP-Link as Access Point behind your actual router and make sure thet the TP-Link is banned by the proper router from accesing the internet. Do not rename the wifi though!
	- Configure the Access Point (see "Configuration"): ssh to the TP-Link and edit /etc/alarm/alarm_ap.conf

2. Adding a myStrom button

	- deactivate MAC filter on the AP (copy allowed MACs before!)
	- AP ESSID should be visible
	- DHCP should be activated
	- Download a special firmware version which allows for unsigned updates from myStrom's GitHub repo: [https://github.com/myStrom/mystrom-button/blob/master/rom/Simple-FW-2.74.12-release.bin](https://github.com/myStrom/mystrom-button/blob/master/rom/Simple-FW-2.74.12-release.bin)
	- Download our custom firmware from the res folder. **The original firmware tries every 12h to reconnect to the AP wich would trigger an alarm twice a day. In the
	custom version this is switched off.** Apart from that it is the original firmware. A loud cheers to myStrom for open-sourcing their firmware! On [https://github.com/myStrom/mystrom-button](https://github.com/myStrom/mystrom-button) you can also find how to recompile the firmware for yourself (it's a bit of a hassle due to outdated sources of dependencies).
	- add buttons:
		- put into config mode (press button for 10 seconds until it flashes white/read)
		- flash the downloaded firmware

			`curl -F file=@Simple-FW-2.74.12-release.bin http://192.168.254.1/load`

		- reset (press for 10 seconds, release, press once)
		- put into config mode (press button for 10 seconds until it flashes white/read)
		- flash our customised firmware from the res folder

			`curl -F file=@Simple-Custom-FW-2.74.12-release.bin http://192.168.254.1/load`

		- connect the button to the AP

			`curl --location -g --request POST 'http://192.168.254.1/api/v1/connect' --data-raw '{ "ssid": "<ALARM-WLANNAME>", "passwd": "<PASSWORD>" }'`

	- Deactivate dhcp
	- Hide essid
	- Reactivate MAC filter (maybe you have to enter all MACs again!)

 
3. CENTRAL

    One of the clients has to serve as a central distributor. This client should be in the LAN all the time or at least be the most reliable node in your LAN. We simply call it CENTRAL here.
You can build the deb-package from source or install it from the codecivil repo:

	- Add codeicivil repo to client:
	
		`cd /etc/apt/sources.list.d/`

		`wget https://www2.codecivil.de/apt/codecivil.bullseye.list`
	  
        (replace bullseye with buster if your are on Debian 10)

		`wget -O - https://www2.codecivil.de/apt/apt\@codecivil.de.pub.asc | apt-key add`

	- Install alarm-central:

		`apt update`

		`apt install alarm-central`

	- After installation, execute as root:
	
	    `alarm-central-postinstall.sh`

	- Set a password for the user alarm on CENTRAL, so clients can later transfer their ssh keys to CENTRAL.
	- Start and enable alarmd as daemon on CENTRAL.
	- Transfer the AP ssh key to CENTRAL: log into the AP and execute /usr/bin/alarm_copy_ap_key.sh

4. Clients

    Clients are the nodes reacting visually and acoustically to alarms. If CENTRAL should do so also, install additionally the client package in CENTRAL.
You can build the deb-package from source or install it from the codecivil repo:

	- Add codeicivil repo to client:
		
        `cd /etc/apt/sources.list.d/`

		`wget https://www2.codecivil.de/apt/codecivil.bullseye.list`

	  (replace bullseye with buster if your are on Debian 10)

		`wget -O - https://www2.codecivil.de/apt/apt\@codecivil.de.pub.asc | apt-key add`

	- Install alarm-client:
		
        `apt update`

		`apt install alarm-client`

	- After installation, execute as root:
	
        `alarm-postinstall.sh`

Configuration
=============

1. AP

    The configuration file is located in /etc/alarm/alarm_ap.conf. 

    * ALARM_NETWORK: the first three octets of your lan; sorry, no other subnet masks supported at this time. End with a dot.
    * ALARM_MAC: identify the mac addresses of your buttons with a human readable name. The identification with a location occurs later when configuring CENTRAL.
    * ALARM_TARGETS: list of last octet of the local IP of the alarm clients, including CENTRAL, but excluding AP.

2. CENTRAL

    - `/etc/alarm/alarm_global_central.conf`
    
        The contents are copied to `/etc/alarm/alarm_global.conf` by alarm-central-postinstall.sh. So either you edit this file before executung alarm-central-postinstall.sh or you simply edit `/etc/alarm/alarm_global.conf` and copy it to
`/etc/alarm/alarm_global_central.conf`. **Make sure that
both filese are identical after you edit one of them; otherwise changes may be lost after a package update or not applied at all.** This is so complicated because the two packages alarm-central and alarm-client cannot share
a common configuration file.

    - `/etc/alarm/alarm_global.conf`

        Contains default definitions to be distributed to all clients. The buttons are identified by the names given in ALARM_MAC of the AP config file (exmaple here: 'buttonname'). The most important definitions are

        - ALARM['DESCRIPTION','buttonname']: This should be the location of the button when being pressed. This description is being displayed in the visual alarm.
    
        - ALARM['AUDIO','buttonname']: The name of the audio file in `/usr/share/alarm/audio/` being used for the alarm

        - ALARM['AUDIO_VOLUME','buttonname']: ranges from 1 to 3

        - ALARM['VIDEO','buttonname']: "fullscreen", "normal" or "" 

        - ALARM['BGCOLOR','buttonname']: background color in #RRGGBB notation 

        - ALARM['FGCOLOR','buttonname']: foreground (font) color in #RRGGBB notation

        - ALARM['IP','buttonname']: IP addresses of clients in the room of the button. If the alarm is triggered, these clients will not react to the alarm and instead be able to give the all-clear signal on the triggered alarm. If you want to separate these features, do not set 'IP' but:

        - ALARM['NOALARM','buttonname']: IP addresses of clients which should not react to the alarm.
        
        - ALARM['ALLCLEAR','buttonname']: IP addresses of clients which are permitted to give the all-clear on the alarm.

        The settings on 'Default' instead of 'buttonname' apply to all buttons. Changes on individual buttons should be stated in the last paragraph of the config file.
  
 3. Clients

     - `/etc/alarm/alarm_global.conf`

        DO NOT EDIT THIS FILE! It is updated regularly from CENTRAL, so any changes here will be lost after the next reboot.

     - `/etc/alarm/alarm_local.conf`

        You can edit this local config file in largely the same way as described for the global config file on CENTRAL. However, you can also use a graphical tool.

     - The graphical tool

        Browse to `System/Control Center/Personal/Alarm Notification Configurator` and use the tool. You can edit the behaviour of the Default or any individual button permanently on the client or for just this session; after the next reboot, the session settings are reset.
