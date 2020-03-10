#!/bin/sh

hostname=$(hostname -I | cut -d' ' -f1)

sed "s/${hostname}:6443/localhost:${KIND_PORT}/g" /etc/kubernetes/admin.conf
