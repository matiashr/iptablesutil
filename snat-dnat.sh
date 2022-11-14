#!/bin/bash
########################### ADAPT THESE ##########################################
##
# public interface and it's ip
##
PUBLIC_DEV=eno1
PUBLIC_IP=$(ip -f inet addr show $PUBLIC_DEV|grep inet|cut -f6 -d" "|cut -f1 -d"/")

##
# internal system interface and destination system ip
##
DESTINATION_DEV=eno2

##
# ports to NAT
#  syntax is : <protocol>:<public port>:<destination port>
##
natports=(
	"tcp:2121:21"
	"tcp:48898:48898"
	"udp:48899:48899"
	"tcp:987:987"
)
############################## END OF SETTINGS ####################################

addforwarding() 
{
	destinationip=$1
	if [ "$destinationip" = "" ]; then
		echo "Bad hostname $1"
		return
	fi
	echo "Forwarding $destinationip "
	for i in ${natports[@]}
	do
		parts=(${i//:/ })
		prot=${parts[0]}
		publicport=${parts[1]}
		internalport=${parts[2]}
		if [ $prot = "tcp" ]; then
			echo "NAT $prot  $publicport -> $internalport /tcp"
			iptables -t nat -I PREROUTING  -p tcp -i $PUBLIC_DEV 	  --dport $publicport -j DNAT --to-destination $destinationip:$internalport
			iptables -t nat -I POSTROUTING -p tcp -o $DESTINATION_DEV --dport $internalport -d $destinationip -j SNAT --to-source $PUBLIC_IP
		fi
		if [ $prot = "udp" ]; then
			echo "NAT $prot  $publicport -> $internalport /udp"
			iptables -t nat -I PREROUTING  -p udp -i $PUBLIC_DEV --dport $publicport -j DNAT --to-destination $destinationip:$internalport
			iptables -t nat -I POSTROUTING -p udp -o $PUBLIC_DEV --dport $publicport -d $destinationip -j SNAT --to-source $PUBLIC_IP
		fi
	done
}

addmasqurade()
{
	echo 1 > /proc/sys/net/ipv4/ip_forward
#	iptables -t nat -A POSTROUTING -o $PUBLIC_DEV -j MASQUERADE
#	iptables -A FORWARD -i $PUBLIC_DEV -j ACCEPT
#	iptables -A FORWARD -i $DESTINATION_DEV -j ACCEPT
}


case "$1" in
  forward)
	  if [ $# = 2 ]; then
	       addforwarding $(nslookup $2| awk 'NR==6 {print $2}')
	  else
		echo "Missing argument, type forward <system hostname>"
	  fi
        ;;
  masq)
	echo "Masqurading"
	addmasqurade
	;;
  show)
  	iptables -t nat -L -v -n --line-numbers
	;;
  listall)
	# show rules with numbers
	iptables -L --line-numbers
	# posible to delete a rule using iptables -D INPUT [N]
	;;
  remove)
	  # TODO:
	  # removes entry by id, but should only remove the entries that was
	  # added
	  iptables -t nat -D PREROUTING $2
	  iptables -t nat -D POSTROUTING $2
	;;
	*)
		echo "Usage " $0 "<forward/masq/show/listall/remove>"
	;;
esac

