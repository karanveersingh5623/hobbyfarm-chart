#!/bin/sh

cd $(dirname $0)
set -e

if ! [ -f /etc/kubeadm-init-ran ]; then
    kubeadm init \
        --apiserver-advertise-address=$(hostname -I | cut -d' ' -f1) \
        --apiserver-cert-extra-sans="127.0.0.1" \
        --apiserver-cert-extra-sans="localhost" \
        --ignore-preflight-errors=all \
        --kubernetes-version=v1.17.0 \
        --pod-network-cidr=10.244.0.0/16 \
        
    touch /etc/kubeadm-init-ran
fi
