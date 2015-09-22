#!/bin/bash

mkdir -p /etc/smilart

#Configuring network
if [ ! -e /etc/smilart/network_installed ]; then
#    ./network-config.sh
    touch /etc/smilart/network_installed
fi


