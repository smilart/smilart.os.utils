#!/bin/bash

sudo systemctl stop skydns.service
sudo systemctl stop etcd2.service
sudo systemctl stop etcd2-cluster.service
sudo systemctl disable skydns.service
sudo systemctl disable etcd2.service


rm -f -R /var/lib/etcd2/*

rm -r /etc/smilart/*

