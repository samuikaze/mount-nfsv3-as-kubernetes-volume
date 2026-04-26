# 透過 NFSv3 將網路磁碟掛載為 Kubernetes 的 Volume

<!-- markdownlint-disable MD028 -->
<!-- markdownlint-disable MD033 -->

本文件會說明如何透過 NFS v3 協定將網路磁碟掛載到 Kubernetes 的 Pod 上。

> 目前測試使用 v3 協定較穩定，v4 協定目前仍需特權容器才能正常讀寫 NFS 系統

> 本範例所實作的內容僅限於內部網路存取，若需要外部網路存取，請自行針對防火牆設定進行調整

> NFSv3 協定對於檔案安全僅認 UID 和 GID，因此若希望有帳號密碼保護的人，SMB 協定也許更符合你的需求

> 官方很多安裝的設定檔都是放在 GitHub 並透過 `raw.githubusercontent.com` 來取得，但現在 GitHub 會阻擋這些疑似爬蟲的自動化工具取得這些內容，因此若遇到 429 錯誤或其他非預期的錯誤導致無法透過工具下載，請先將設定檔下載下來後直接部署即可

## Table of Contents

- [事前準備](#事前準備)
- [建立 NFS 上的 share](#建立-nfs-上的-share)
- [安裝 Container Storage Interface (CSI)](#安裝-container-storage-interface-csi)
  - [透過 Helm 安裝 (建議)](#透過-helm-安裝-建議)
  - [透過 kubectl 安裝](#透過-kubectl-安裝)
- [PV 自動製備](#pv-自動製備)
- [安全性](#安全性)
  - [NFS 系統上的 Squash](#nfs-系統上的-squash)
  - [設定 share 的可存取性](#設定-share-的可存取性)
  - [設定 SELinux](#設定-selinux)
- [測試 NFS 存取](#測試-nfs-存取)
  - [具備安裝 StorageClass](#具備安裝-storageclass)
  - [未安裝 StorageClass](#未安裝-storageclass)
- [參考資料](#參考資料)

## 事前準備

在實作前，需先準備以下項目

- 一個單一或多節點的 Kubernetes 叢集
- 一個支援 NFS 協定的網路儲存設備或網路儲存裝置

## 建立 NFS 上的 share

再進行任何 CSI 安裝或 Volume 掛載前，需要先有 share 資料夾的存在，因此需先登入 NFS 系統後，建立一個可以透過 NFS 協定掛載的 share 資料夾

由於目前市面上有許多支援 NFS 協定的網路磁碟裝置或系統，請參照該廠商的說明手冊完成以下兩個步驟:

1. 建立共用資料夾 (share)
2. 開啟 NFS 協定的支援

## 安裝 Container Storage Interface (CSI)

完成 NFS share 的建立後，接下來就是要讓 Kubernetes 支援 NFS 協定了，透過安裝 Kubernetes 官方提供的 [csi-driver-nfs](https://github.com/kubernetes-csi/csi-driver-nfs) CSI 驅動程式就可以達成，這個部分可以選擇使用 kubectl 或直接透過 Helm 進行安裝。

> 由於 CSI 算是 Kubernetes 所需的系統功能，因此範例會直接將這個 CSI 安裝到 `kube-system` 命名空間中

### 透過 Helm 安裝 (建議)

這邊如果是透過 Helm 進行安裝，可以搭配 `kubernetes-yamls` 資料夾下的 `install.sh` 與 `nsf-csi-values.yaml` 檔案進行安裝，安裝前記得先調整 `nsf-csi-values.yaml` 中:

- 依據實際狀況設定 `runOnMaster`、`runOnControlPlane`
- `defaultOnDeletePolicy`: 選擇當 PV 被移除時 CSI 對於 NFS 上建立的資料夾與檔案應該如何處理
- `storageClass` 所有相關設定
  > 若要部署多個 StorageClass，請將 `storageClass` 整個區塊註解掉，並透過下面的 `storageClasses` 進行安裝

以及 `install.sh` 中的:

- `VERSION`: 透過 [官方的 Release 查閱最新版本](https://github.com/kubernetes-csi/csi-driver-nfs/releases)或你想指定的版本
- `NAMESPACE`: 要安裝到哪個命名空間中，建議使用預設的 `kube-system` 即可

### 透過 kubectl 安裝

透過 kubectl 安裝請參照[官方文件的說明](https://github.com/kubernetes-csi/csi-driver-nfs/blob/master/docs/install-nfs-csi-driver.md)安裝，安裝完成後可以透過 `kubernetes-yamls/storage-class.yaml` 部署 Storage Class，部署前記得先調整相關設定

## PV 自動製備

Kubernetes 對於 NFS 是支援 PV 的自動製備的，其需透過 StorageClass 來達成目的，而 StorageClass 的部分在前面都有部署了，可以透過指令 `kubectl get storageclass` 來確認

只要 StorageClass 存在，只要宣告 PVC 後，Kubernetes 就會在 NFS 中依據 StorageClass 的設定自動建立 PV 與實際的儲存空間

> 不同的 StorageClass 可以設定到相同的 NFS 上，**但掛載的資料夾不建議相同**，因此若有這類需求，需要注意掛載資料夾的路徑

## 安全性

本節會針對目前可以調整的安全性方面進行說明

### NFS 系統上的 Squash

**⚠️ 請特別注意！！**

網路上很多教學文章會要你把 squash 調整為「將所有使用者調整為 admin」選項，如果是使用 nfsv3 進行掛載，squash 的部分**使用預設的「不調整」即可**，在非 nfsv4 或非更高的協定情形下，不須將透過 nfs 連入的客戶端視為 Root 或 admin 也可以操作檔案系統，你也不需要為了這個需求特地將系統的 admin 與 user 啟用，請以最高安全性來設定。

> [!TIP]
> 也許「不調整」不是最安全的設定，請依據自行的需求來調整與測試權限，這邊僅提醒大家網路上的文章設定都是為了安裝方便，安全性的調教仍然需要注意與調整

> nfsver4.1 建議透過 Kerberos 來加強安全性

### 設定 share 的可存取性

NFS 可以設定哪些 IP 可以存取，請依據實際狀況將 IP Pool 設到 NFS 的 share 上，例如 Kubernetes 叢集的 IP 是 `192.168.100.0/24`，請直接將這個 IP Pool 設定上去

### 設定 SELinux

SELinux 預設是不允許 Container 存取 NFS 協定的網路磁碟，因此需要開通 SELinux 的權限，透過以下指令允許 Container 對於 NFS 協定的存取

> [!NOTE]
> 若你使用的系統並沒有安裝 SELinux，請跳過這個區塊的說明

```bash
sudo semanage boolean --modify --on virt_use_nfs
```

指令執行完後會立即套用，不需要進行重開機

## 測試 NFS 存取

官方提供了[動態製備](https://github.com/kubernetes-csi/csi-driver-nfs/blob/master/deploy/example/README.md#storage-class-usage-dynamic-provisioning)與[靜態製備](https://github.com/kubernetes-csi/csi-driver-nfs/blob/master/deploy/example/README.md#pvpvc-usage-static-provisioning)兩種範例，因此:

### 具備安裝 StorageClass

若前面安裝的 StorageClass 沒有移除，可以直接透過部署[動態製備](https://github.com/kubernetes-csi/csi-driver-nfs/blob/master/deploy/example/README.md#storage-class-usage-dynamic-provisioning)的 yaml 後，透過指令 `kubectl get pv` 來確認 PV 的建立狀態，並實際到 NFS 系統上確認指定的資料夾有沒有被建立起來。

最重要的是請部署一支服務來測試 PV 的讀寫，一般來說掛載起來後走 nfsv3 一定可以讀寫，但為了安全起見，請分別掛載兩支服務，其內部執行的 UID 與 GID 設定為不同，並同時掛載相同的 PV 測試全縣有沒有正常

### 未安裝 StorageClass

前面安裝的 StorageClass 如果被移除，要嘛裝回來走上面的測試方式，不然就是透過[靜態製備](https://github.com/kubernetes-csi/csi-driver-nfs/blob/master/deploy/example/README.md#pvpvc-usage-static-provisioning)的方式測試手動建立 PV 與權限，其測試方式與[具備安裝 StorageClass](#具備安裝-storageclass) 相同，僅有 PV 需要手動部署。

## 參考資料

- [kubernetes-csi/csi-driver-nfs - GitHub](https://github.com/kubernetes-csi/csi-driver-nfs)
- [Volume - Kubernetes 文檔](https://kubernetes.io/zh-cn/docs/concepts/storage/volumes/)
- [Storage Classes - Kubernetes 文檔](https://kubernetes.io/zh-cn/docs/concepts/storage/storage-classes/)
- [How to modify SELinux settings with booleans - RadHat](https://www.redhat.com/en/blog/change-selinux-settings-boolean)
- [Configure a Security Context for a Pod or Container - Kubernetes 文檔](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Pods having permissions issue with NFS share #396 - kubernetes-csi/csi-driver-nfs - GitHub Discussions](https://github.com/kubernetes-csi/csi-driver-nfs/discussions/396)
- [StorageClass應用：NFS](https://weng-albert.medium.com/storageclass%E6%87%89%E7%94%A8-nfs-b33651b55cca)
- [How to Set Up Persistent Storage with NFS in Kubernetes](https://oneuptime.com/blog/post/2026-01-22-kubernetes-persistent-storage-nfs/view)
- [Stop using raw.githubusercontent as chart repository #995](https://github.com/kubernetes-csi/csi-driver-nfs/issues/995)
