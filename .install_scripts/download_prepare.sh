#!/bin/bash

echo 
echo "#####################################################"
echo "### DOWNLOAD AND PREPARE OPENSHIFT 4 INSTALLATION ###"
echo "#####################################################"
echo



echo -n "====> Creating and using directory ${SETUP_DIR}: "
mkdir -p ${SETUP_DIR} && cd ${SETUP_DIR} || err "using ${SETUP_DIR} failed"
ok

echo -n "====> Creating a hosts file for this cluster (/etc/hosts.${CLUSTER_NAME}): "
touch /etc/hosts.${CLUSTER_NAME} || err "Creating /etc/hosts.${CLUSTER_NAME} failed"
ok

echo -n "====> Creating a dnsmasq conf for this cluster (${DNS_DIR}/${CLUSTER_NAME}.conf): "
echo "addn-hosts=/etc/hosts.${CLUSTER_NAME}" > ${DNS_DIR}/${CLUSTER_NAME}.conf || err "Creating ${DNS_DIR}/${CLUSTER_NAME}.conf failed"
ok

echo -n "====> SSH key to be injected in all VMs: "
if [ -z "${SSH_PUB_KEY_FILE}" ]; then
    ssh-keygen -f sshkey -q -N "" || err "ssh-keygen failed"
    export SSH_PUB_KEY_FILE="sshkey.pub"; ok "generated new ssh key"
elif [ -f "${SSH_PUB_KEY_FILE}" ]; then
    ok "using existing ${SSH_PUB_KEY_FILE}"
else
    err "Unable to select SSH public key!"
fi
    

echo -n "====> Downloading OCP Client: "; download get "$CLIENT" "$CLIENT_URL";
echo -n "====> Downloading OCP Installer: "; download get "$INSTALLER" "$INSTALLER_URL";
tar -xf "${CACHE_DIR}/${CLIENT}" && rm -f README.md
tar -xf "${CACHE_DIR}/${INSTALLER}" && rm -f rm -f README.md

echo -n "====> Downloading RHCOS Image: "; download get "$IMAGE" "$IMAGE_URL";
echo -n "====> Downloading RHCOS Kernel: "; download get "$KERNEL" "$KERNEL_URL";
echo -n "====> Downloading RHCOS Initramfs: "; download get "$INITRAMFS" "$INITRAMFS_URL";

mkdir rhcos-install
cp "${CACHE_DIR}/${KERNEL}" "rhcos-install/vmlinuz"
cp "${CACHE_DIR}/${INITRAMFS}" "rhcos-install/initramfs.img"
cat <<EOF > rhcos-install/.treeinfo
[general]
arch = x86_64
family = Red Hat CoreOS
platforms = x86_64
version = ${OCP_VER}
[images-x86_64]
initrd = initramfs.img
kernel = vmlinuz
EOF


mkdir install_dir
cat <<EOF > install_dir/install-config.yaml
apiVersion: v1
baseDomain: ${BASE_DOM}
compute:
- hyperthreading: Disabled
  name: worker
  replicas: 0
controlPlane:
  hyperthreading: Disabled
  name: master
  replicas: ${N_MAST}
metadata:
  name: ${CLUSTER_NAME}
networking:
  clusterNetworks:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  none: {}
pullSecret: '${PULL_SEC}'
sshKey: '$(cat ${SSH_PUB_KEY_FILE})'
additionalTrustBundle: | 
    -----BEGIN CERTIFICATE-----
    MIIDtzCCAp+gAwIBAgIUYDGV8RumqV5Gqj60uahbxjYI1LUwDQYJKoZIhvcNAQEL
    BQAwajELMAkGA1UEBhMCVVMxCzAJBgNVBAgMAlZBMREwDwYDVQQHDAhOZXcgWW9y
    azENMAsGA1UECgwEUXVheTERMA8GA1UECwwIRGl2aXNpb24xGTAXBgNVBAMMEHF1
    YXkubTRkM2J1Zy5jb20wHhcNMjMwNjIzMTY0NjI3WhcNMjYwNDEyMTY0NjI3WjBq
    MQswCQYDVQQGEwJVUzELMAkGA1UECAwCVkExETAPBgNVBAcMCE5ldyBZb3JrMQ0w
    CwYDVQQKDARRdWF5MREwDwYDVQQLDAhEaXZpc2lvbjEZMBcGA1UEAwwQcXVheS5t
    NGQzYnVnLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM4R+djs
    jmKh10BtMrtM/Gz08l+OF1cKE0CCMGikzY+ZsHCgbsM958gnoYnCQ/5xlKgwtDMt
    6iM6/DeQ+UchBxd0DuppsLS+rzDnuSsKtkqwZZVHGWsxKdjkoYvvHhTGfrENMqeY
    Ta7aVmQR5dK/LzeHuXvUZy7rOVjqYoFJ5zjh3AfKCf+2RAmxA12mwcaRasK0j/rf
    nOC4nkEau8aikEJDrLlaqJ+GFa8E2m+lhfiKSk9zRGgcYNYQSZe69VaqijU38nHC
    cXUFHynxBFh1MHlq3nlAlU+rK275e9Hll3RFbyCyNgTc9KU6tJxwTFyVJR2WTsh4
    EDIjBrp6AfTiZvkCAwEAAaNVMFMwCwYDVR0PBAQDAgLkMBMGA1UdJQQMMAoGCCsG
    AQUFBwMBMBsGA1UdEQQUMBKCEHF1YXkubTRkM2J1Zy5jb20wEgYDVR0TAQH/BAgw
    BgEB/wIBATANBgkqhkiG9w0BAQsFAAOCAQEAGcYQiVW1TawiEcKp6uNnup4SXUF/
    +EVB0MDDXEVDXUrxhI4facTH33n4nGZpp0jZ+zxv0j6rxtYrU3IH7SNnjUHHazqZ
    nq/2abVFQ6BfFXRwNPMMb+gGJ7FhXar2U43XWs5yhBEtboKWigq6/cvdo745mOWU
    iaFnth0P6Q6hjHcwniT15mxMAjYst3gosWlZQuHDF0yGavVWnb8miwzKxnCuDyFc
    Mf1M6ul637m2kG3bzSCXGbmS3F1QDTeq1jOIp0dfnXwX51Czqp0KxIWJEn/OS8ax
    BT4drq7aHe1DqDoHsdqwdIT3hzFFmCLXwsI6tLcly5yxeR17tXX0Y7JsLA==
    -----END CERTIFICATE-----
imageContentSources:
- mirrors:
  - quay.m4d3bug.com/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - quay.m4d3bug.com/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOF


echo "====> Creating ignition configs: "
./openshift-install create ignition-configs --dir=./install_dir || \
    err "./openshift-install create ignition-configs --dir=./install_dir failed"

WS_PORT="1234"
cat <<EOF > tmpws.service
[Unit]
After=network.target
[Service]
Type=simple
WorkingDirectory=/opt
ExecStart=/usr/bin/python -m SimpleHTTPServer ${WS_PORT}
[Install]
WantedBy=default.target
EOF



echo "
global
  log 127.0.0.1 local2
  chroot /var/lib/haproxy
  pidfile /var/run/haproxy.pid
  maxconn 4000
  user haproxy
  group haproxy
  daemon
  stats socket /var/lib/haproxy/stats

defaults
  mode tcp
  log global
  option tcplog
  option dontlognull
  option redispatch
  retries 3
  timeout queue 1m
  timeout connect 10s
  timeout client 1m
  timeout server 1m
  timeout check 10s
  maxconn 3000
# 6443 points to control plan
frontend ${CLUSTER_NAME}-api *:6443
  default_backend master-api
backend master-api
  balance source
  server bootstrap bootstrap.${CLUSTER_NAME}.${BASE_DOM}:6443 check" > haproxy.cfg
for i in $(seq 1 ${N_MAST})
do
    echo "  server master-${i} master-${i}.${CLUSTER_NAME}.${BASE_DOM}:6443 check" >> haproxy.cfg
done
echo "

# 22623 points to control plane
frontend ${CLUSTER_NAME}-mapi *:22623
  default_backend master-mapi
backend master-mapi
  balance source
  server bootstrap bootstrap.${CLUSTER_NAME}.${BASE_DOM}:22623 check" >> haproxy.cfg
for i in $(seq 1 ${N_MAST})
do
    echo "  server master-${i} master-${i}.${CLUSTER_NAME}.${BASE_DOM}:22623 check" >> haproxy.cfg
done
echo "
# 80 points to master nodes
frontend ${CLUSTER_NAME}-http *:80
  default_backend ingress-http
backend ingress-http
  balance source" >> haproxy.cfg
for i in $(seq 1 ${N_MAST})
do
    echo "  server master-${i} master-${i}.${CLUSTER_NAME}.${BASE_DOM}:80 check" >> haproxy.cfg
done
echo "
# 443 points to master nodes
frontend ${CLUSTER_NAME}-https *:443
  default_backend infra-https
backend infra-https
  balance source" >> haproxy.cfg
for i in $(seq 1 ${N_MAST})
do
    echo "  server master-${i} master-${i}.${CLUSTER_NAME}.${BASE_DOM}:443 check" >> haproxy.cfg
done

