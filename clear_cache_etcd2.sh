#!/bin/bash

sudo systemctl stop skydns.service
sudo systemctl stop etcd2.service

rm -f -R /var/lib/etcd2/*

rm -r /etc/smilart/*

