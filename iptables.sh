#!/usr/bin/env bash

# Set the default policy of the INPUT chain to DROP
iptables -F INPUT
iptables -P INPUT DROP

# Accept incoming SSH connections
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --sport 22 -j ACCEPT

# Accept incoming bind connections
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -p tcp --sport 53 -j ACCEPT

# Accept incoming http/https connections
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --sport 80 -j ACCEPT
iptables -A INPUT -p tcp --sport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Accept incoming freeradius connections
iptables -A INPUT -p udp --dport 2083 -j ACCEPT
iptables -A INPUT -p udp --sport 2083 -j ACCEPT
iptables -A INPUT -p tcp --dport 2083 -j ACCEPT
iptables -A INPUT -p tcp --sport 2083 -j ACCEPT

iptables -A INPUT -p udp --dport 1812 -j ACCEPT
iptables -A INPUT -p udp --sport 1812 -j ACCEPT

# Accept ping requests
iptables -A INPUT -p icmp --icmp-type 8 -s 0/0 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type 0 -s 0/0 -m state --state ESTABLISHED,RELATED -j ACCEPT
