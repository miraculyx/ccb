#!/usr/bin/perl
#
#  Copyright (c) 2004 Gerhard Lange.
#
#	This is free software and is provided "as is" without express or implied warranty. 
#  
#	This copyright applies to all code included in this distribution.
#
#	This program is free software, you can redistribute it and/or modify it under 
#	the terms of the GNU General Public License as published by the Free Software 
#	Foundation version 2 of the License.
#
#	This program is distributed in the hope that it will be useful, but WITHOUT ANY 
#	WARRANTY, without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
#	PARTICULAR PURPOSE. 
#
#	see the GNU General Public License for more details. 
#
# Author:      Gerhard Lange
# Description: Program for backing up the configuration of CISCO devices
# Date:        07/06/2004
my $version = "Version 3.0";
#
# Modifications: 
# 1.2 -> 2.0   : Recognition of Routers with IOS 12.0 or greater
#                Catalyst 650x/ 550x are now included        
# 2.0 -> 2.1   : Error in RegularExpression:
#                ( $sysdescr =~ m/C35|C29|WS-C(4|5)50|Version [1-11]/), now
#                ( $sysdescr =~ m/$SWITCHES|$OLD_VERSION/)
#                 because earlies IOS Version is the 10.3

# Insert the Switches, which function with "CISCO-STACK-MIB MIB"
# my $STACK_SWITCHES = "WS-C([4,5,6]...|29..)";
my $STACK_SWITCHES = "WS-C....";

# Insert the Switches and Routers, which have the MIB "OLD-CISCO-SYS-MIB" 
my $SWITCHES = "72033_rp|WS-C1200|WS-C1600|WS-C1700|1800|1900|2100|WS-C2600|2800|2820|2900|2940|2948G|2950|2955|2970|WS-C3000|3500|3550|3560|WS-C3750|3900|85(10|40)";
my $OLD_VERSION = "Version (10|11)";

# Bisherige SNMP Module:
use SNMP_util;
use SNMP_Session;
#
# Neue Moeglichkeit:
use Net::SNMP;

# require 'C:\Perl\lib\Net\BER.pm';
# require 'C:\Perl\lib\Net\SNMP_util.pm';
# require 'C:\Perl\lib\Net\SNMP_Session.pm';

use strict;
use IO::Handle; 

$SNMP_Session::suppress_warnings = 2;
$SNMP_Session::recycle_socket = 1;  

my ($device_file,$tftp_server,$rw_community,$timeout,$prefix,$suffix) = @ARGV;

if (! defined ($timeout)) { $timeout = 15; }
if (! defined ($prefix)) { $prefix = "/"; }       # TFTP-Server Root-Directory
if (! defined ($suffix)) { $suffix = ".wri"; } 

my $community = "public";
my $oid_file = "cisco.oid";
my $model;
my $legenda="Legenda :\n 0 : O.K.\n 1 : No response\n 2 : No write-Access to TFTP-Server\nxx : Other Error, please see help\n\n\n\n";

my ($sec, $min, $hr, $mday, $mon, $year, @etc) = localtime(time);
$mon++; $year=$year+1900;  
# my $now=sprintf("%.4d%.2d%.2d", $year, $mon, $mday); 
my $today=sprintf("%.2d/%.2d/%.4d", $mday, $mon, $year );
# $suffix = "_$now"."$suffix"; 

my $prg_name = $0;
$prg_name =~ s|^.*[\\/]||; 

# Usage: 
my $usage="Usage: \n$prg_name <file> <TFTP-Server> [rw-community] [timeout] [TFTP directory] [Suffix]\n[]: optional Parameter\n"; 
my $help="\nAuthor: Gerhard Lange\nStores  all  CISCO  device configurations on\na TFTP-Server via SNMP.\nThe  device-file  <file>  contains  all  the\naddresses of the devices.\nIt is possible to insert the SNMP-Communitys\ninto the device-file.\n";
$prg_name =~ s|\.(.){1,3}$||; 
my $log_file = $prg_name . ".log"; 

if (! defined ($ARGV[0])) { print "$version\n$usage"; exit; }
if (($ARGV[0] =~ m/-(\?|help|h)/i)) { print "$help\n$usage"; exit; }

$SIG{'INT'} = sub {
	print LOGFILE "-"x82,"\n";
	printf LOGFILE $legenda;
	print "-"x82,"\n";
	printf $legenda;
	print STDERR "Termination of program ... !\n";	
	exit;
};

sub convert_date {
	my (@z)=@_; $z[4] +=1; $z[5] +=1900;
	foreach (0 .. 5) { if ($z[$_]<10) { $z[$_]="0".$z[$_]; } } 
  return ("$z[2]:$z[1]:$z[0]");
}

sub find_model { 
# Get SNMP Product OID of the device
my $ciscoProducts="1.3.6.1.4.1.9.1";
my ($device,$community,$oid_file)=@_;
my $iod = ".1.3.6.1.2.1.1.2.0"; 
my ($sys_type) = &snmpget("$community\@$device",$iod);
# my $sys_type = ($response);
my $model_oid;
my $mod;
open(OID_FILE, $oid_file); 
# or die "Couldn't open the file <$device_file> !\n";   
while (my $record = <OID_FILE>) {
	if ($record !~ /^(#|!|\s)/) {
		chomp($record);
		# Fuehrende Whitespaces entfernen !
		# $record =~ s/^\s(.*)\s/$1/i;   
		# Only read the first and the last word of the line
		my ($mib,$mod) = (split(/:/,$record))[0,-1];
		if ($mib eq ($sys_type)) { $model_oid=$mod; }
	}
}
close(OID_FILE);
my($sysdescr) = &snmpget("$community\@$device",".1.3.6.1.2.1.1.1.0"); 
if (!defined ($model_oid)) {
	if (( $sysdescr =~ m/(IOS \(tm\)|Cisco Systems|Cisco Secure)\s([a-z,-]*\s*[0-9]*)/i)) {
		# What we are searching for is now in REG-EXPRESSION memory 2 !
		$model_oid = $2;
    open(OID_FILE, ">>$oid_file"); 
		if ($sys_type =~ /$ciscoProducts/) {
			# Save only CISCO Models in the File !
			printf OID_FILE "$sys_type:$model_oid\n"; 
		}
		close(OID_FILE);
	}
}
return ($sysdescr,$model_oid);
}

sub old_cisco_sys_mib {  
# Router/ Switch with CISCO IOS Version 11.0 or older, using OLD-CISCO-SYS-MIB "writeNet" 
my ($device,$community,$conf_file,$tftp_server)=@_;
my $iod = ".1.3.6.1.4.1.9.2.1.55.$tftp_server";   
my ($response) = &snmpset("$community\@$device",$iod,'string', $conf_file); 
my $i = 0;
while ((!($response)) and ($i < 6)) {  
	# Stop trying to get the configuration file after 30 seconds
	sleep (5); ($response) = &snmpset("$community\@$device",$iod,'string', $conf_file); $i++;   
} 
if (defined ($response)) { return 0; } else { return 2; } 
} # END old_cisco_sys_mib


sub cisco_flash_mib { 	
# Support for "CISCO-FLASH-MIB"
my ($device,$community,$conf_file,$tftp_server)=@_;
my @snmp_packet; 
my $SUCCESS = 3;
my $status;
# Random number in the range [0 .. 1000]
my $random_num = int ((rand (1))*1000);
push (@snmp_packet,$community.'@'.$device);  
push (@snmp_packet,".1.3.6.1.4.1.9.9.96.1.1.1.1.2.".$random_num,'integer', 1); 
push (@snmp_packet,".1.3.6.1.4.1.9.9.96.1.1.1.1.3.".$random_num,'integer', 4); 
push (@snmp_packet,".1.3.6.1.4.1.9.9.96.1.1.1.1.4.".$random_num,'integer', 1); 
push (@snmp_packet,".1.3.6.1.4.1.9.9.96.1.1.1.1.5.".$random_num,'ipaddr', $tftp_server);
push (@snmp_packet,".1.3.6.1.4.1.9.9.96.1.1.1.1.6.".$random_num,'string', $conf_file); 
# If all parameters are send in one SNMP-Packet "4:createAndGo" will start the download
push (@snmp_packet,".1.3.6.1.4.1.9.9.96.1.1.1.1.14.".$random_num,'integer', 4);
my $response = &snmpset(@snmp_packet);

# Check, if device has completed the configuration download with success
my $iod = ".1.3.6.1.4.1.9.9.96.1.1.1.1.10.".$random_num; 
($response) = &snmpget("$community\@$device",$iod); 
my $i = 0;
while (($response != $SUCCESS) and ($i < 6)) {  
	# Stop polling after 30 seconds, if there is no positive aknowledge from device
	sleep (5); ($response) = &snmpget("$community\@$device",$iod); $i++;   
} 
if ( $response == $SUCCESS) { 
	return 0; } 
	else { 
		# It could be, that some 12.x Images don't have implemted the FLASH-MIB;
		# for example the "c3620-ds-mz-122-2-T.bin" Image !
		$status = &old_cisco_sys_mib ($device,$community,$conf_file,$tftp_server);
		if ($status != 0) { return ($response + 10)}
}
} # END cisco_flash_mib


sub cisco_stack_mib { 
# With this function will be saved the configuration of the CATx50y
# Catalyst Switches.  
# Will function with all devices, which support "CISCO-STACK-MIB MIB":
# CATALYST 650x and CATALYST 3550 (some sort of images)
# http://www.cisco.com/c/en/us/support/docs/ip/simple-network-management-protocol-snmp/13504-move-files-images-snmp.html
#
my ($device,$community,$conf_file,$tftp_server)=@_;  
my @snmp_packet;
my $SUCCESS = 2;
push (@snmp_packet,$community.'@'.$device);   
push (@snmp_packet,".1.3.6.1.4.1.9.5.1.5.1.0",'string', $tftp_server); 
push (@snmp_packet,".1.3.6.1.4.1.9.5.1.5.2.0",'string', $conf_file); 
push (@snmp_packet,".1.3.6.1.4.1.9.5.1.5.3.0",'integer', 1);
push (@snmp_packet,".1.3.6.1.4.1.9.5.1.5.4.0",'integer', 3); 
my $response = &snmpset(@snmp_packet);

# Check, if device has completed the configuration download with success
my $iod = ".1.3.6.1.4.1.9.5.1.5.5.0";
($response) = &snmpget("$community\@$device",$iod); 
my $i = 0;
while (($response != $SUCCESS) and ($i < 6)) {  
	# Stop polling after 30 seconds, if there is no positive acknowledge from device
	sleep (5); ($response) = &snmpget("$community\@$device",$iod); 	$i++;     
} 
if ( $response == $SUCCESS) { return 0; }  else { return ($response + 20); }
} # END cisco_stack_mib


sub backup { 
my ($device,$community,$prefix,$suffix)=@_; 
my $status = 1; # No response from device
my $sysName; 
my $chassisId; 
my $version;
my $feature;
my $model;
my $sysdescr;

($sysName) = &snmpget("$community\@$device",".1.3.6.1.2.1.1.5.0");

# Only the part until the first dot (".") will be used for the "sysName"
if ($sysName =~ /\./) { $sysName =~ s/^(.+?)\..*$/$1/; }
my $conf_file = "$prefix"."$sysName"."$suffix"; 

if ( defined ($sysName)  ) { 
	($sysdescr,$model) = &find_model($device,$community,$oid_file);
	if (! defined ($model)  ) {
		if (( $sysdescr =~ m/(IOS \(tm\)|Cisco Systems|Cisco Secure)\s([a-z,-]*\s*[0-9]*)/i)) {
			# What we are searching for is now in REG-EXPRESSION memory 2 !
			$model = $2;
		}
	}
	if (( $sysdescr =~ m/(Version)\s([0-9,.,(,),-,a-z]*)/i)) {
	# What we are searching for is now in meomory 2 !
	$version = $2;
	}
	if (( $sysdescr =~ m/(-)([0-9,a-z]*)(-)/i)) {
		# What we are searching for is now in meomory 2 !
		$feature = $2;
	}
	$version = "$version"." "."$feature";

	if (( $sysdescr =~ m/($STACK_SWITCHES)/)) {
		# In einigen Tests hat es Probleme mit der Erkennung der CAT.5.. Modelle gegeben
		# um sicher zu gehen, dass diese richtig erkannt werden, wird die obige 
		# Switch-Stack Deklaration verwendet.
		# $model = $1;
  $status = &cisco_stack_mib ($device,$community,$conf_file,$tftp_server);
  ($chassisId) = snmpget("$community\@$device",".1.3.6.1.4.1.9.5.1.2.19.0");
  if (!defined ($chassisId)) { 
  	# Chassis Serial-Number is not a String, is an Integer
  	($chassisId) = snmpget("$community\@$device",".1.3.6.1.4.1.9.5.1.2.17.0");
   } 
	} else { 
		($chassisId) = snmpget("$community\@$device",".1.3.6.1.4.1.9.3.6.3.0"); 
		if (( $sysdescr =~ m/$SWITCHES|$OLD_VERSION/)) {		
			$status = &old_cisco_sys_mib ($device,$community,$conf_file,$tftp_server);
		} else { 
			# $sysdescr =~ m/Version 1[2-9]/
			$status = &cisco_flash_mib ($device,$community,$conf_file,$tftp_server);	
		}
	} 
} else { $status = 1; }
return ($sysName,$model,$chassisId,$version,$status);            
} # END backup 


# Main-Program   
open(INIFILE, $device_file) or die "Couldn't open the file <$device_file> !\n";   

my $act_time = &convert_date(localtime(time));  
print "\n\nDevice Configuration BACKUP Report made at $today $act_time\n"; 
print "TFTP-Server: $tftp_server\n"; 
print "Directory:   $prefix\n\n\n"; 

printf "%-17s%-13s%-21s%-20s%+8s\n","Hostname","Model","Serial-Number","Version","Status";                                 
print "-"x82,"\n";
                        
open (LOGFILE, ">>$log_file") or die "Couldn't open the Log-file !\n";
printf LOGFILE "Device Configuration BACKUP Report made at $today $act_time\n"; 
printf LOGFILE "TFTP-Server: $tftp_server\n";
printf LOGFILE "Directory:   $prefix\n\n\n"; 
printf LOGFILE "%-17s%-13s%-21s%-20s%+8s\n","Hostname","Model","Serial-Number","Version","Status";                 
print LOGFILE "-"x82,"\n";

my $good = 0; my $total = 0;
while (my $record = <INIFILE>) {
	if ($record !~ /^(#|!|\s)/) {
	# The line will not be ignored, if not marked as a comment
		my @record_array = split(/;/,$record); my $device = $record_array[0]; chomp($device); 
		if (($rw_community ne "")) { 
			chomp($rw_community); $community=$rw_community;
		} else { $community=$record_array[1]; }
		chomp($community);
		if ($device ne "") {
			my ($name,$model,$chassisId,$version,$status) = &backup($device,$community,"$prefix","$suffix"); 
			if (! defined($name)) { $name = $device; }
			printf "%-17s%-13s%-21s%-20s%+8s\n",$name,$model,$chassisId,$version,$status; 
			printf LOGFILE "%-17s%-13s%-21s%-20s%+8s\n",$name,$model,$chassisId,$version,$status; 
			if ($status == 0) { $good++; sleep ($timeout); } else { sleep ($timeout/3); }
			$total++;
	 	} 
	}
}
close(INIFILE);

print "-"x82,"\n"; print LOGFILE "-"x82,"\n";
$act_time = &convert_date(localtime(time)); 
printf "%-10s%66s/%s\n\n", $act_time,$good, $total; 
printf LOGFILE "%-10s%66s/%s\n\n", $act_time,$good, $total; 
print $legenda; printf LOGFILE $legenda;
close (LOGFILE); 



__END__ 



=head1 NAME

CCB - created by Gerhard Lange

=head1 SYNOPSIS

This PERL Script fetches all  CISCO  device configurations (running configuration) 
to a seperate TFTP-Server via SNMP. 
The  device-file B<"file"> contains  all  the addresses (or names) of the devices. 
It is also possible to insert the SNMP-Communitys into this device-file, if they 
differ from each other.
You have to know the SNMP READ-WRITE Community String of the CISCO devices.

As a result of the operation, it will be printed a short inventory of the network devices (Hostname, Model-Type, Serial-Number and Software Version) and the status 
of the operation for each device. 

	

=head1 DESCRIPTION

The script first gets the Hostname of the device (system.sysName.0). 
According to the result of this first operation it was also checked, if the device is 
alive and ready for the configuration transfer.
In the second step the script gets the system description (system.sysDescr.0) via a SNMP GET Request 
to recognize the type of device (Router or Switch) and the software version (CAT-OS, IOS 11.0 or fewer, IOS 12.0 or 
later, etc.). According to these information, it will be send the neccessary SNNPSET command to 
initiate the transfer of the running configuration of the device via the TFTP protocol. 
In the 3rd step the script gets the Chassis Serial-Number of the device. 
The script prints out the start time and the time at which the last device has
been finished. 

It is not possible to save the configuration of a CISCO PIX Firewall with this 
script, because there is no such Read-Write SNMP Community in a CISCO PIX Firewall.

The SNMP MIBs, which are used in this PERL Script for fetching the configuration files can be divided into these three groups:

	SNMP MIB 		Packet-Size	Device Types/ Images
	CISCO-STACK-MIB 	174 Bytes	CISCO CATALYST Switches
	CISCO-FLASH-MIB		229 Bytes	Routers IOS with 12.0 or higher
	OLD-CISCO-SYS-MIB	113 Bytes	old IOS and IOS Switches

SNMP MIBs for getting the Serial-Numbers:

	.1.3.6.1.4.1.9.5.1.2.17.0 (CISCO chassisSerialNumber)
	.1.3.6.1.4.1.9.5.1.2.19.0 (CISCO chassisSerialNumberString)
	.1.3.6.1.4.1.9.3.6.3.0  	-> see "snmp-server chassis-id"

Used SNMP MIB-2 Variables:

	.iso.org.dod.internet.mgmt.mib-2.system.sysName.0
	.iso.org.dod.internet.mgmt.mib-2.system.sysDescr.0
	.iso.org.dod.internet.mgmt.mib-2.system.sysObjectID.0



Timeout Parameter

This is the amount of time, that the script should wait before doing the operation with the next 
device, if the last operation was successfully. A successfully operation means, that the device 
has communicated a positive aknowledge via a SNMPGET Request at the end of the operation. 
The script tries to get a positive response six times from a device with a delay of 5 seconds
between every try, before printing out an error-message (-> Merror Message, Status). 
It takes approximately 20 minutes to get all the configuration files of circa 200 devices, with an 
timeout of 2 seconds.

The default value of "timeout" is 15 seconds.



=head1 Device-file

The construction of the device-file can be made in two different ways.
  
	CASE A:

	In the case, you have different SNMP comunity-strings for every device in your network.
	You have to specify the devices (IP address or names) in the file and the coresponding 
	SNMP Read-Write Community String for this device. 
	The last ";" is not required, but it helps to see if there are spaces added at the end 
	of a community-string. You can insert comments in your device-file. 
	All comments start with an "#", "!" or an whitespace (SPACE, TAB).

	In the following example all the configuration files will be saved into the directory 
	/ROMA/ of the TFTP-Server (192.168.1.1). 
	The "" indicates to consider the Community-Strings from the device-file.
	There is a timeout of 5 seconds between one and an other device fetching.

		# Start of the Network Device File
		rtr-rm-023;write;
		sw-rm-009;tulpe;
		192.168.1.253;orange;
		! Backbone
		192.168.10.1;secret;  
		gw-rm-007;secret; 
		# End of Network Device File
		
ccb.pl device.txt 192.168.1.1 "" 5 /ROMA/
	
  
	CASE B: 
  
	In the case, you have the same SNMP comunity-string for every device, it is not 
	neccessary to insert the SNMP Community-string into the device-file. It is important 
	to specify only the IP Addresses of the devices (or IP Names) in the file. 
	All other community-strings, which are inserted in the device-file ("secret" in 
	line 2 in this example), will be ignored now. 
	The last ";" is not required, but it helps to see if you have added spaces at the 
	end of the Device-Name.

	In the following example all the configuration files will be saved into the directory 
	/MILANO/ of the TFTP-Server. The SNMP Community-String for all devices is "write".
	There is a timeout of 2 seconds between one and an other device fetching. 
	All the configuration files have a Suffix of "*.cfg". The Default Suffix is "*.wri".
	
		! Start of the Network Device File
		gw-mi-23;
		sw-mi-core1;secret
		192.168.10.253
		192.168.10.1
		! End of Network Device File
	
ccb.pl device.txt tftp-server write 2 /MILANO/ .cfg


=head1	CISCO device configurations

The CISCO devices should have a minimal configuration for doing SNMP:

I<B<CISCO IOS Router/ Switch:>>

	snmp-server community <READ-ONLY> RO
	snmp-server community <READ-WRITE> RW 

	Optional configuration lines:
	snmp-server chassis-id <serial-number>
	alias exec wrnet copy running-config tftp://<tftp-server>//<config_file-name>
	

I<B<CISCO CATALYST Switches:>>

	set snmp community read-only <READ-ONLY>
	set snmp community read-write <READ-WRITE>
	set snmp community read-write-all <READ-WRITE-ALL>


I<B<CISCO PIX Firewall:>>

	tftp-server inside <tftp-server> /<config_file-name>
	snmp-server host inside <tftp-server>
	snmp-server community <READ-ONLY>
	telnet <tftp-server> 255.255.255.255 inside

=head1	TFTP-Server Setup under LINUX

TFTP-Server Setup under LINUX

1) Install the RPM Modul under Redhat:
   rpm -ivh tftp-server-0.33-2.i386.rpm

2) Modify the configuration-file "tftp" of the TFTP-Server

   Goto the "xinetd.d" directory 

cd /etc/xinetd.d
ls tftp      <- File for the configuration of the TFTP-Server

	[root@linux xinetd.d]# cat tftp
	# default: off
	# description: The tftp server serves files using the trivial file transfer \
	#       protocol.  The tftp protocol is often used to boot diskless \
	#       workstations, download configuration files to network-aware printers, \
	#       and to start the installation process for some operating systems.
	service tftp
	{
	        socket_type             = dgram
	        protocol                = udp
        	wait                    = yes
        	user                    = root
        	server                  = /usr/sbin/in.tftpd
        	server_args             = -c -s /tftpboot
        	disable                 = no
        	per_source              = 11
        	cps                     = 100 2
        	flags                   = IPv4
	}


The arguments "server_args = -c -s /tftpboot" allow to upload any file
and give the permission of the creation of new sub-directorys.


3) Restart the Network-Services of "xinetd": service xinetd restart

4) Verify, if TFTP-Server (69/ udp) is UP: netstat -an | grep udp


=head1	TFTP-Server under Windows

There are some free TFTP-Servers under Windows: 

	http://www.firewall.cx/download-s01-ftp.php
	ftp://ftp.3com.com/pub/utilbin/win32/3cdv2r10.zip
	ftp://ftp.3com.com/pub/utilbin/win32/3CTftpSvc.zip
	http://www.cisco.com/pcgi-bin/tablebuild.pl/tftp
	http://solarwinds.net/Tools/Free_Tools/TFTP_Server/
	ftp://216.60.197.200/unsupported/

It is important, that the TFTP-Server is configured to allow to overwrite existing files.

Tip: You should choose an TFTP-Server that can be installed as a Windows service, that can be scheduled with the backup of your configuration files.

=head1	Model-Typs

All used model types will be recognised by the content of the SNMP MIB ".iso.org.dod.internet.mgmt.mib-2.system.sysObjectID.0" and will be written
into the file "B<cisco.oid>". This file can than be edited.

	# start of "cisco.oid"
	! Here are some old 2500 Models
	1.3.6.1.4.1.9.1.42:C2516
	1.3.6.1.4.1.9.1.19:C2503
	# The CISCO 7000 Models of the network
	1.3.6.1.4.1.9.1.8:C7000
	1.3.6.1.4.1.9.1.12:C7010
	1.3.6.1.4.1.9.1.209:C2621	
	1.3.6.1.4.1.9.1.340:C3662Ac
	1.3.6.1.4.1.9.1.414:C3725

You can find a helpfull tool to convert the SNMP OIDs 
into the CISCO Model Types, which you have in your network at the following link:

http://tools.cisco.com/Support/SNMP/do/BrowseOID.do?local=en


=head1 USAGE

	ccb.pl <file> <TFTP-Server> [rw-community] [timeout] [TFTP-Server directory] [Suffix]
	[]: optional Parameter
		

=head1 EXAMPLE

		ccb.pl device.txt tftp1 write-community 15 /ROUTER/
		ccb.pl device.txt tftp2 write-community 15 /SWITCH/

=head1 ERROR Messages

This is the list of all possible Messages during the SNMP/ TFTP File Transfer 
of the device configuration file:

	 0	O.K.
	 1	no response from device, or wrong SNMP Community-String

	 2	no write-Access to TFTP-Server, or file-name still exists

	11	Waiting
	12	Running
	14	Failed 

	21	Operation in Progress
	23	no Response from device
	24	too many retries
	25	no Buffers
	26	no Processes
	27	bad Checksum
	28	bad Length
	29	bad Flash
	30	Server Error
	31	User Canceled
	32	Wrong Code
	33	File not Found
	34	Invalid TFTP Host
	35	Invalid Tftp Module
	36	Access Violation
	37	Unknown Status
	38	Invalid Storage Device
	39	Insufficient Space on Storage Device
	40	Insufficient DRAM Size
	41	Incompatible Image

=head1 Standalone under Windows

This Script was tested with the PERL Version "v5.8.3 built for MSWin32-x86-multi-thread".
It is also possible to build this script as "standalone" with an PERL Packer. If the script is packed, it is not neccessary to install a PERL Interpreter, but you have 
to install the file "perl58.dll" in one of the directories, which will be indicated by the DOS "path" command.

=head1 COPYRIGHT

  Copyright (c) 2004 Gerhard Lange.

	This is free software and is provided "as is" without express or implied warranty. 
  
	This copyright applies to all code included in this distribution.

	This program is free software, you can redistribute it and/or modify it under 
	the terms of the GNU General Public License as published by the Free Software 
	Foundation version 2 of the License.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY 
	WARRANTY, without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
	PARTICULAR PURPOSE. 

	see the GNU General Public License for more details. 

=head1 AUTHOR

Gerhard Lange E<lt>lange.gerhard@gmail.comE<gt>

=cut


