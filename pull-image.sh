#!/bin/bash
export PRODUCT_REPO='openshift-release-dev'
export RELEASE_NAME="ocp-release"
export OCP_RELEASE=4.12.46
export ARCHITECTURE=x86_64
export LOCAL_REGISTRY='quay.madebug.net'
export LOCAL_REPOSITORY='ocp4/openshift4'
export LOCAL_SECRET_JSON=/root/ocp4_setup_upi_kvm/pull-secret

/root/ocp4_cluster_ocp412/oc adm -a ${LOCAL_SECRET_JSON} release mirror --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}
