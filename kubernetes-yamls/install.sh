#!/bin/bash

# Remember to change the version and namespace name
VERSION=4.13.2
NAMESPACE=kube-system

# Recommand using this command to deploy the csi driver
helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
    --namespace $NAMESPACE \
    --version $VERSION \
    -f ./nfs-csi-values.yaml

# Or using the command below if you don't need values.yaml to configure the settings
# Remember to comment out the command above
# helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
# helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
#     --namespace $NAMESPACE \
#     --version $VERSION \
#     --set externalSnapshotter.enabled=true \
#     --set controller.runOnControlPlane=true \
#     --set volumeSnapshotClass.create=true \
#     --set storageClass.create=true
