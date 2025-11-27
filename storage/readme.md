# storage

This directory contains all persistent storage configurations for the ELK stack, organized by resource type.

----

## directory structure

- `pv/` - PersistentVolume definitions
- `pvc/` - PersistentVolumeClaim definitions
- `elasticsearch-storageclass.yaml` - StorageClass for Elasticsearch

----

## storage architecture

The storage system uses three layers:

- Host directories at /mnt/ssd (physical storage)
- PersistentVolumes (Kubernetes storage abstraction)
- PersistentVolumeClaims (application storage requests)

----

## persistent volumes (pv/)

PersistentVolumes represent physical storage on the host.

#### files

- `elasticsearch-node-0-pv.yaml` - Elasticsearch node 0 storage (20Gi)
- `kibana-pv.yaml` - Kibana saved objects storage (5Gi)

#### characteristics

- Cluster-scoped resources
- Retain policy prevents automatic deletion
- HostPath type for local storage

#### adding nodes

When scaling Elasticsearch to 3 nodes, create additional PVs:

- `elasticsearch-node-1-pv.yaml` (copy and modify node-0)
- `elasticsearch-node-2-pv.yaml` (copy and modify node-0)

----

## persistent volume claims (pvc/)

PersistentVolumeClaims request storage for applications.

#### files

- `kibana-pvc.yaml` - Kibana deployment storage claim

#### notes

- Elasticsearch and Logstash use volumeClaimTemplates (auto-created)
- Only Kibana requires manual PVC definition
- PVCs are namespace-scoped (k3s-elk)

----

## storage class

`elasticsearch-storageclass.yaml` defines storage provisioning behavior:

- Provisioner: rancher.io/local-path (k3s default)
- Binding mode: WaitForFirstConsumer
- Reclaim policy: Retain

----

## storage sizes

#### development (current)

- Elasticsearch: 20Gi per pod
- Logstash: 10Gi per pod
- Kibana: 5Gi total
- Total: 35Gi

#### production (recommended)

- Elasticsearch: 100Gi per pod
- Logstash: 20Gi per pod
- Kibana: 10Gi total
- Total: 350Gi (3 ES + 2 LS + 1 KB)

----

## setup

Storage directories are created by `setup.sh`:

```bash
/mnt/ssd/elasticsearch/node-0  # Elasticsearch data
/mnt/ssd/kibana-data           # Kibana saved objects
```

Logstash storage is auto-provisioned at `/var/lib/rancher/k3s/storage/pvc-*`

----

## related documentation

- [../docs/storage.md](../docs/storage.md) - complete storage architecture guide
- [../docs/production-resources.md](../docs/production-resources.md) - storage planning and sizing
- [../docs/scaling.md](../docs/scaling.md) - scaling storage with replicas
- [../readme.md](../readme.md) - project overview
