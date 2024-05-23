#!/bin/bash

login_vm() {
	local vm_host_mac="<MAC_HERE>"
	local vm_host_ip=$(arp -a | grep -i "${vm_host_mac}" | awk '{ print $1 }')
	if [[ -z "$vm_host_ip" ]]
	then
		echo "host ip not found for mac: ${vm_host_mac}"
	else
		ssh -l ibrahim ${vm_host_ip}
	fi
}