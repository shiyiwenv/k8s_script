#!/bin/bash

#auther: syw
#优化lvs 机器

ethname=$1

#yum install -y epel* ipvsadm keepalived

#lvs hash table size
cat > /etc/modprobe.d/ip_vs.conf <<EOF 
options ip_vs conn_tab_bits=20
EOF

##keepalived iptables
#-A INPUT -s 175.25.166.0/24 -p vrrp -j ACCEPT

#ring buffer
ethtool -G $ethname rx 4096
ethtool -G $ethname tx 4096

#queue size
sysctl -w net.core.netdev_max_backlog=262144

#
ethtool -K $ethname lro off
ethtool -K $ethname gro off
