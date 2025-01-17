<h1>DESCRIPTION</h1>
<p>This PERL Script fetches all  CISCO  device configurations (running configuration) 
to a seperate TFTP-Server via SNMP. 
The  device-file <strong>&quot;file&quot;</strong> contains  all  the addresses (or names) of the devices. 
It is also possible to insert the SNMP-Communitys into this device-file, if they 
differ from each other.
You have to know the SNMP READ-WRITE Community String of the CISCO devices.</p>
<p>As a result of the operation, it will be printed a short inventory of the network devices (Hostname, Model-Type, Serial-Number and Software Version) and the status 
of the operation for each device.</p>

<p>The script first gets the Hostname of the device (system.sysName.0). 
According to the result of this first operation it was also checked, if the device is 
alive and ready for the configuration transfer.
In the second step the script gets the system description (system.sysDescr.0) via a SNMP GET Request 
to recognize the type of device (Router or Switch) and the software version (CAT-OS, IOS 11.0 or fewer, IOS 12.0 or 
later, etc.). According to these information, it will be send the neccessary SNNPSET command to 
initiate the transfer of the running configuration of the device via the TFTP protocol. 
In the 3rd step the script gets the Chassis Serial-Number of the device. 
The script prints out the start time and the time at which the last device has
been finished.</p>
<p>It is not possible to save the configuration of a CISCO PIX Firewall with this 
script, because there is no such Read-Write SNMP Community in a CISCO PIX Firewall.</p>
<p>The SNMP MIBs, which are used in this PERL Script for fetching the configuration files can be divided into these three groups:</p>
<pre>
        SNMP MIB                Packet-Size     Device Types/ Images
        CISCO-STACK-MIB         174 Bytes       CISCO CATALYST Switches
        CISCO-FLASH-MIB         229 Bytes       Routers IOS with 12.0 or higher
        OLD-CISCO-SYS-MIB       113 Bytes       old IOS and IOS Switches</pre>
<p>SNMP MIBs for getting the Serial-Numbers:</p>
<pre>
        .1.3.6.1.4.1.9.5.1.2.17.0 (CISCO chassisSerialNumber)
        .1.3.6.1.4.1.9.5.1.2.19.0 (CISCO chassisSerialNumberString)
        .1.3.6.1.4.1.9.3.6.3.0          -&gt; see &quot;snmp-server chassis-id&quot;</pre>
<p>Used SNMP MIB-2 Variables:</p>
<pre>
        .iso.org.dod.internet.mgmt.mib-2.system.sysName.0
        .iso.org.dod.internet.mgmt.mib-2.system.sysDescr.0
        .iso.org.dod.internet.mgmt.mib-2.system.sysObjectID.0</pre>
<b>Timeout Parameter</b>
<p>This is the amount of time, that the script should wait before doing the operation with the next 
device, if the last operation was successfully. A successfully operation means, that the device 
has communicated a positive aknowledge via a SNMPGET Request at the end of the operation. 
The script tries to get a positive response six times from a device with a delay of 5 seconds
between every try, before printing out an error-message (-&gt; Merror Message, Status). 
It takes approximately 20 minutes to get all the configuration files of circa 200 devices, with an 
timeout of 2 seconds.</p>
<p>The default value of &quot;timeout&quot; is 15 seconds.</p>
<hr />
<h1>Device-file</h1>
<p>The construction of the device-file can be made in two different ways.</p>
<pre>
<b>CASE A:</b>
<p>In the case, you have different SNMP comunity-strings for every device in your network. You have to specify the
devices IP address or names) in the file and the coresponding SNMP Read-Write Community String for this device. 
The last ";" is not required, but it helps to see if there are spaces added at the end of a community-string.
You can insert comments in your device-file. All comments start with an "#", "!" or an whitespace (SPACE, TAB).</p>

<p>In the following example all the configuration files will be saved into the directory /ROMA/ of the
TFTP-Server (192.168.1.1). The "" indicates to consider the Community-Strings from the device-file.
There is a timeout of 5 seconds between one and an other device fetching.</p>

/# Start of the Network Device File
rtr-rm-023;write;
sw-rm-009;tulpe;
192.168.1.253;orange;
! Backbone
192.168.10.1;secret;  
gw-rm-007;secret; 
/# End of Network Device File

ccb.pl device.txt 192.168.1.1 "" 5 /ROMA/


<b>CASE B:</b>                
<p>In the case, you have the same SNMP comunity-string for every device, it is not neccessary to insert the
SNMP Community-string into the device-file. It is important to specify only the IP Addresses of the devices
(or IP Names) in the file. 
All other community-strings, which are inserted in the device-file ("secret" in line 2 in this example),
will be ignored now. 
The last ";" is not required, but it helps to see if you have added spaces at the end of the Device-Name.</p>

<p>In the following example all the configuration files will be saved into the directory /MILANO/ of the
TFTP-Server.
The SNMP Community-String for all devices is "write". There is a timeout of 2 seconds between one and an
other device fetching. 
All the configuration files have a Suffix of "*.cfg". The Default Suffix is "*.wri".</p>
        
/#  Start of the Network Device File
gw-mi-23;
sw-mi-core1;secret
192.168.10.253
192.168.10.1
/# End of Network Device File
        
ccb.pl device.txt tftp-server write 2 /MILANO/ .cfg

</pre>

<h1>CISCO device configurations</h1>
<p>The CISCO devices should have a minimal configuration for doing SNMP:</p>
<p><em><strong>CISCO IOS Router/ Switch:</strong></em></p>
<pre>
        snmp-server community &lt;READ-ONLY&gt; RO
        snmp-server community &lt;READ-WRITE&gt; RW</pre>
<pre>
        Optional configuration lines:
        snmp-server chassis-id &lt;serial-number&gt;
        alias exec wrnet copy running-config tftp://&lt;tftp-server&gt;//&lt;config_file-name&gt;</pre>
<p><em><strong>CISCO CATALYST Switches:</strong></em></p>
<pre>
        set snmp community read-only &lt;READ-ONLY&gt;
        set snmp community read-write &lt;READ-WRITE&gt;
        set snmp community read-write-all &lt;READ-WRITE-ALL&gt;</pre>
<p><em><strong>CISCO PIX Firewall:</strong></em></p>
<pre>
        tftp-server inside &lt;tftp-server&gt; /&lt;config_file-name&gt;
        snmp-server host inside &lt;tftp-server&gt;
        snmp-server community &lt;READ-ONLY&gt;
        telnet &lt;tftp-server&gt; 255.255.255.255 inside</pre>
<p>
</p>
<hr />
<h1><a name="tftp_server_setup_under_linux">TFTP-Server Setup under LINUX</a></h1>
<p>TFTP-Server Setup under LINUX</p>
<p>1) Install the RPM Modul under Redhat:
   rpm -ivh tftp-server-0.33-2.i386.rpm</p>
<p>2) Modify the configuration-file &quot;tftp&quot; of the TFTP-Server</p>
<pre>
   Goto the &quot;xinetd.d&quot; directory</pre>
<p>cd /etc/xinetd.d
ls tftp      &lt;- File for the configuration of the TFTP-Server</p>
<pre>
        <span class="operator">[</span><span class="variable">root</span><span class="variable">@linux</span> <span class="variable">xinetd</span><span class="operator">.</span><span class="variable">d</span><span class="operator">]</span><span class="comment"># cat tftp</span>
        <span class="comment"># default: off</span>
        <span class="comment"># description: The tftp server serves files using the trivial file transfer \</span>
        <span class="comment">#       protocol.  The tftp protocol is often used to boot diskless \</span>
        <span class="comment">#       workstations, download configuration files to network-aware printers, \</span>
        <span class="comment">#       and to start the installation process for some operating systems.</span>
        <span class="variable">service</span> <span class="variable">tftp</span>
        <span class="operator">{</span>
                <span class="variable">socket_type</span>             <span class="operator">=</span> <span class="variable">dgram</span>
                <span class="variable">protocol</span>                <span class="operator">=</span> <span class="variable">udp</span>
                <span class="keyword">wait</span>                    <span class="operator">=</span> <span class="variable">yes</span>
                <span class="variable">user</span>                    <span class="operator">=</span> <span class="variable">root</span>
                <span class="variable">server</span>                  <span class="operator">=</span> <span class="regex">/usr/sbin</span><span class="operator">/</span><span class="variable">in</span><span class="operator">.</span><span class="variable">tftpd</span>
                <span class="variable">server_args</span>             <span class="operator">=</span> <span class="keyword">-c</span> <span class="keyword">-s</span> <span class="operator">/</span><span class="variable">tftpboot</span>
                <span class="variable">disable</span>                 <span class="operator">=</span> <span class="keyword">no</span>
                <span class="variable">per_source</span>              <span class="operator">=</span> <span class="number">11</span>
                <span class="variable">cps</span>                     <span class="operator">=</span> <span class="number">100</span> <span class="number">2</span>
                <span class="variable">flags</span>                   <span class="operator">=</span> <span class="variable">IPv4</span>
        <span class="operator">}</span>
</pre>
<p>The arguments &quot;server_args = -c -s /tftpboot&quot; allow to upload any file
and give the permission of the creation of new sub-directorys.</p>
<p>3) Restart the Network-Services of &quot;xinetd&quot;: service xinetd restart</p>
<p>4) Verify, if TFTP-Server (69/ udp) is UP: netstat -an | grep udp</p>
<p>
</p>
<hr />
<h1><a name="tftp_server_under_windows">TFTP-Server under Windows</a></h1>
<p>There are some free TFTP-Servers under Windows:</p>
<pre>
        <a href="http://www.firewall.cx/download-s01-ftp.php">http://www.firewall.cx/download-s01-ftp.php</a>
        <a href="ftp://ftp.3com.com/pub/utilbin/win32/3cdv2r10.zip">ftp://ftp.3com.com/pub/utilbin/win32/3cdv2r10.zip</a>
        <a href="ftp://ftp.3com.com/pub/utilbin/win32/3CTftpSvc.zip">ftp://ftp.3com.com/pub/utilbin/win32/3CTftpSvc.zip</a>
        <a href="http://www.cisco.com/pcgi-bin/tablebuild.pl/tftp">http://www.cisco.com/pcgi-bin/tablebuild.pl/tftp</a>
        <a href="http://solarwinds.net/Tools/Free_Tools/TFTP_Server/">http://solarwinds.net/Tools/Free_Tools/TFTP_Server/</a>
        <a href="ftp://216.60.197.200/unsupported/">ftp://216.60.197.200/unsupported/</a></pre>
<p>It is important, that the TFTP-Server is configured to allow to overwrite existing files.</p>
<p>Tip: You should choose an TFTP-Server that can be installed as a Windows service, that can be scheduled with the backup of your configuration files.</p>
<p>
</p>
<hr />
<h1><a name="model_typs">Model-Typs</a></h1>
<p>All used model types will be recognised by the content of the SNMP MIB &quot;.iso.org.dod.internet.mgmt.mib-2.system.sysObjectID.0&quot; and will be written
into the file &quot;<strong>cisco.oid</strong>&quot;. This file can than be edited.</p>
<pre>
        # start of &quot;cisco.oid&quot;
        ! Here are some old 2500 Models
        1.3.6.1.4.1.9.1.42:C2516
        1.3.6.1.4.1.9.1.19:C2503
        # The CISCO 7000 Models of the network
        1.3.6.1.4.1.9.1.8:C7000
        1.3.6.1.4.1.9.1.12:C7010
        1.3.6.1.4.1.9.1.209:C2621       
        1.3.6.1.4.1.9.1.340:C3662Ac
        1.3.6.1.4.1.9.1.414:C3725</pre>
<p>You can find a helpfull tool to convert the SNMP OIDs 
into the CISCO Model Types, which you have in your network at the following link:</p>
<p><a href="http://tools.cisco.com/Support/SNMP/do/BrowseOID.do?local=en">http://tools.cisco.com/Support/SNMP/do/BrowseOID.do?local=en</a></p>
<p>
</p>
<hr />
<h1><a name="usage">USAGE</a></h1>
<pre>
        ccb.pl &lt;file&gt; &lt;TFTP-Server&gt; [rw-community] [timeout] [TFTP-Server directory] [Suffix]
        []: optional Parameter</pre>
<p>
</p>
<hr />
<h1><a name="example">EXAMPLE</a></h1>
<pre>
                ccb.pl device.txt tftp1 write-community 15 /ROUTER/
                ccb.pl device.txt tftp2 write-community 15 /SWITCH/</pre>
<p>
</p>
<hr />
<h1><a name="error_messages">ERROR Messages</a></h1>
<p>This is the list of all possible Messages during the SNMP/ TFTP File Transfer 
of the device configuration file:</p>
<pre>
         0      O.K.
         1      no response from device, or wrong SNMP Community-String</pre>
<pre>
         2      no write-Access to TFTP-Server, or file-name still exists</pre>
<pre>
        11      Waiting
        12      Running
        14      Failed</pre>
<pre>
        21      Operation in Progress
        23      no Response from device
        24      too many retries
        25      no Buffers
        26      no Processes
        27      bad Checksum
        28      bad Length
        29      bad Flash
        30      Server Error
        31      User Canceled
        32      Wrong Code
        33      File not Found
        34      Invalid TFTP Host
        35      Invalid Tftp Module
        36      Access Violation
        37      Unknown Status
        38      Invalid Storage Device
        39      Insufficient Space on Storage Device
        40      Insufficient DRAM Size
        41      Incompatible Image</pre>
<p>
</p>
<hr />
<h1>Standalone under Windows</h1>
<p>This Script was tested with the PERL Version &quot;v5.8.3 built for MSWin32-x86-multi-thread&quot;.
It is also possible to build this script as &quot;standalone&quot; with an PERL Packer.
If the script is packed, it is not neccessary to install a PERL Interpreter, but you have 
to install the file &quot;perl58.dll&quot; in one of the directories, which will
be indicated by the DOS &quot;path&quot; command.</p>
<p>
</p>
<hr />
