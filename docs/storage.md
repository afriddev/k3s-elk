# Storage Configuration

## Overview

This document explains the persistent storage architecture for the ELK stack. All data is stored on the host to ensure it survives pod restarts, node reboots, and cluster maintenance operations.

----

## Storage Architecture

#### Three-Layer Design

The storage system uses three abstraction layers:

Host Directories at /mnt/ssd provide physical storage on the Kubernetes node. These directories are created by the setup.sh script and survive cluster deletion and pod restarts. Data persists even when Kubernetes is completely removed from the system.

PersistentVolumes provide Kubernetes abstraction of host storage. These use hostPath type pointing to /mnt/ssd directories. The reclaim policy is set to Retain which prevents automatic data deletion. These are cluster-wide resources and are not namespace-scoped.

PersistentVolumeClaims request storage for applications. These are bound to specific PVs using label selectors or StorageClass. They are mounted into application pods and are namespace-scoped resources in k3s-elk.

----

## Component Storage Details

#### Elasticsearch Storage

- Deployment type: StatefulSet with volumeClaimTemplates
- Storage method: Automatic dynamic provisioning via volumeClaimTemplate
- Capacity: 50Gi per pod
- Mount point: /usr/share/elasticsearch/data
- StorageClass: elasticsearch-local-storage
- Host path base: /mnt/ssd/elasticsearch/

Data stored includes:

- Index data and segment files
- Translog for durability
- Cluster state information
- Snapshot metadata

Each Elasticsearch pod receives automatic PVC:

- data-elasticsearch-0 for first pod
- data-elasticsearch-1 for second pod
- data-elasticsearch-2 for third pod

#### Logstash Storage

- Deployment type: StatefulSet with volumeClaimTemplates
- Storage method: Automatic dynamic provisioning
- Capacity: 10Gi per pod
- Mount point: /usr/share/logstash/data
- StorageClass: local-path
- Auto-provisioned path: /var/lib/rancher/k3s/storage/pvc-UUID

Data stored includes:

- Dead letter queue for failed events
- Persistent queue data
- Pipeline state and checkpoints
- Plugin temporary files

Each Logstash pod receives automatic PVC:

- logstash-data-logstash-0 for first pod
- logstash-data-logstash-1 for second pod
- logstash-data-logstash-2 for third pod

#### Kibana Storage

- Deployment type: Standard Deployment with PVC
- Storage method: Manual PV and PVC binding
- Capacity: 5Gi total
- Mount point: /usr/share/kibana/data
- Host path: /mnt/ssd/kibana-data
- PV name: kibana-data-pv
- PVC name: kibana-data-pvc

Data stored includes:

- Saved searches and queries
- Dashboard configurations
- Visualizations
- Index patterns
- User preferences and settings

----

## Storage Files

#### Elasticsearch Storage

- `storage/elasticsearch-storageclass.yaml` - StorageClass with Retain policy
- `storage/pv/elasticsearch-node-0-pv.yaml` - PersistentVolume for first node
- `statefulsets/elasticsearch-statefulset.yaml` - Contains volumeClaimTemplates

#### Logstash Storage

- Uses default local-path StorageClass from k3s
- No explicit PV files needed
- `statefulsets/logstash-statefulset.yaml` - Contains volumeClaimTemplates

#### Kibana Storage

- `storage/pv/kibana-pv.yaml` - PersistentVolume definition
- `storage/pvc/kibana-pvc.yaml` - PersistentVolumeClaim definition

----

## Setup Process

#### Host Directory Creation

The `setup.sh` script creates required directories:

```bash
/mnt/ssd/
├── elasticsearch/
│   └── node-0/
└── kibana-data/
```

Logstash storage directories are created automatically by k3s local-path provisioner in /var/lib/rancher/k3s/storage/.

#### Permissions Configuration

Elasticsearch requires UID 1000 ownership:

```bash
chown -R 1000:1000 /mnt/ssd/elasticsearch
chmod -R 755 /mnt/ssd/elasticsearch
```

Kibana uses standard permissions:

```bash
chmod -R 777 /mnt/ssd/kibana-data
```

#### Storage Deployment

The `deploy.sh` script applies storage manifests in this order:

- StorageClass resources
- PersistentVolume resources
- PersistentVolumeClaim resources
- Application deployments that mount the storage

----

## Data Persistence Guarantees

#### Events That Do Not Cause Data Loss

- Pod restart or deletion
- Pod rescheduling to different node (if using network storage)
- Deployment or StatefulSet updates
- Rolling updates
- Manual kubectl delete pod
- Node reboot (data remains on disk)
- Cluster upgrade operations
- Namespace deletion with PV Retain policy

#### Events That Cause Data Loss

- Manual deletion of /mnt/ssd directories on host
- Physical disk failure without backup
- Intentional kubectl delete pv command
- Formatting or reimaging node without backup
- Setting reclaim policy to Delete and removing PVC

----

## Verification Commands

#### Check Persistent Volumes

```bash
kubectl get pv
```

Expected output shows Bound status for all volumes.

#### Check Persistent Volume Claims

```bash
kubectl get pvc -n k3s-elk
```

All PVCs should show Bound status.

#### Describe Specific Resources

```bash
kubectl describe pv elasticsearch-node-0-pv
kubectl describe pvc data-elasticsearch-0 -n k3s-elk
kubectl describe pvc kibana-data-pvc -n k3s-elk
```

#### Check Host Directories

```bash
sudo ls -lah /mnt/ssd/elasticsearch/node-0/
sudo ls -lah /mnt/ssd/kibana-data/
sudo df -h /mnt/ssd
```

#### Check Pod Volume Mounts

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- df -h /usr/share/elasticsearch/data
kubectl exec -n k3s-elk logstash-0 -- df -h /usr/share/logstash/data
kubectl exec -n k3s-elk deployment/kibana -- df -h /usr/share/kibana/data
```

----

## Storage Sizing

#### Current Allocations

- Elasticsearch: 50Gi per pod (index data, high growth potential)
- Logstash: 10Gi per pod (queue only, low growth)
- Kibana: 5Gi total (metadata only, minimal growth)

#### Growth Patterns

Elasticsearch storage grows based on log retention policy and ingestion rate. Monitor index sizes and implement ILM (Index Lifecycle Management) for automatic index deletion.

Logstash storage remains relatively stable as it only buffers messages. Queue depth depends on processing rate versus ingestion rate.

Kibana storage grows slowly with saved objects. 5Gi is sufficient for most use cases even with hundreds of dashboards.

#### Monitoring Storage Usage

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl http://localhost:9200/_cat/indices?v
kubectl exec -n k3s-elk elasticsearch-0 -- df -h /usr/share/elasticsearch/data
```

----

## Backup Procedures

#### Elasticsearch Backup

Full data backup requires stopping the pod:

```bash
kubectl scale statefulset elasticsearch --replicas=0 -n k3s-elk
sudo tar -czf elasticsearch-backup-$(date +%Y%m%d).tar.gz /mnt/ssd/elasticsearch
kubectl scale statefulset elasticsearch --replicas=1 -n k3s-elk
```

Alternative using Elasticsearch Snapshot API (preferred for production):

```bash
# Configure snapshot repository
curl -XPUT "http://<node-ip>:30920/_snapshot/my_backup" -H 'Content-Type: application/json' -d '{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/backups"
  }
}'

# Create snapshot
curl -XPUT "http://<node-ip>:30920/_snapshot/my_backup/snapshot_$(date +%Y%m%d)"
```

#### Kibana Backup

```bash
kubectl scale deployment kibana --replicas=0 -n k3s-elk
sudo tar -czf kibana-backup-$(date +%Y%m%d).tar.gz /mnt/ssd/kibana-data
kubectl scale deployment kibana --replicas=1 -n k3s-elk
```

#### Logstash Backup

Logstash queue data is transient and typically does not require backup. If needed:

```bash
kubectl scale statefulset logstash --replicas=0 -n k3s-elk
sudo tar -czf logstash-pvcs-$(date +%Y%m%d).tar.gz /var/lib/rancher/k3s/storage
kubectl scale statefulset logstash --replicas=1 -n k3s-elk
```

----

## Restore Procedures

#### Restore Elasticsearch Data

```bash
kubectl scale statefulset elasticsearch --replicas=0 -n k3s-elk
sudo rm -rf /mnt/ssd/elasticsearch/node-0/*
sudo tar -xzf elasticsearch-backup-YYYYMMDD.tar.gz -C /
sudo chown -R 1000:1000 /mnt/ssd/elasticsearch
kubectl scale statefulset elasticsearch --replicas=1 -n k3s-elk
```

#### Restore Kibana Data

```bash
kubectl scale deployment kibana --replicas=0 -n k3s-elk
sudo rm -rf /mnt/ssd/kibana-data/*
sudo tar -xzf kibana-backup-YYYYMMDD.tar.gz -C /
kubectl scale deployment kibana --replicas=1 -n k3s-elk
```

----

## Storage Expansion

#### Elasticsearch Volume Expansion

Cannot expand StatefulSet PVCs without recreation. Process:

- Backup existing data
- Delete StatefulSet (keep PVCs): kubectl delete statefulset elasticsearch -n k3s-elk --cascade=orphan
- Delete PVCs: kubectl delete pvc data-elasticsearch-0 -n k3s-elk
- Edit StatefulSet volumeClaimTemplates to new size
- Recreate StatefulSet: kubectl apply -f statefulsets/elasticsearch-statefulset.yaml
- Restore data if necessary

#### Kibana Volume Expansion

For hostPath volumes expansion is not applicable. Ensure /mnt/ssd has sufficient space. The 5Gi allocation in PV is a soft limit for hostPath.

#### Logstash Volume Expansion

Same process as Elasticsearch using StatefulSet recreation.

----

## Troubleshooting

#### PVC Stuck in Pending

```bash
kubectl describe pvc <pvc-name> -n k3s-elk
```

Common causes:

- No PV available matching StorageClass
- Label selector mismatch between PV and PVC
- Insufficient capacity available
- AccessMode incompatibility
- StorageClass not found

#### Pod Cannot Mount Volume

```bash
kubectl describe pod <pod-name> -n k3s-elk
```

Common causes:

- PVC not bound to PV
- Host directory does not exist
- Permission denied on host path
- Volume already mounted by another pod (for RWO volumes)
- Path mismatch between PV hostPath and actual directory

#### Permission Denied Errors

Fix Elasticsearch permissions:

```bash
sudo chown -R 1000:1000 /mnt/ssd/elasticsearch
sudo chmod -R 755 /mnt/ssd/elasticsearch
```

Fix Kibana permissions:

```bash
sudo chmod -R 777 /mnt/ssd/kibana-data
```

#### Disk Space Issues

Check available space:

```bash
df -h /mn/ssd
```

Find large indices:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl http://localhost:9200/_cat/indices?v&s=store.size:desc
```

Delete old indices:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XDELETE http://localhost:9200/logs-2024.01.01
```

----

## Migration Procedures

#### Moving to New Node

- Backup data from old node using tar or snapshot
- Run `[setup.sh]` on new node to create directories
- Restore data to /mnt/ssd on new node
- Deploy ELK stack using `[deploy.sh]`
- Verify data integrity

#### Changing Storage Location

- Update host paths in all PV YAML files
- Create new directories at new location
- Migrate data: sudo mv /mnt/ssd/elasticsearch /new/path/elasticsearch
- Delete old PVs: kubectl delete pv <pv-names>
- Apply updated PV configurations
- Restart pods to bind to new PVs

----

## Best Practices

- Schedule regular automated backups of /mnt/ssd directories
- Monitor disk usage and set alerts at 80 percent threshold
- Implement Elasticsearch ILM for automatic old index deletion
- Test backup restoration procedures quarterly
- Document all storage modifications in this file
- Review capacity requirements quarterly based on growth trends
- Use Elasticsearch snapshots for production-grade backups
- Keep at least one week of backup history
- Verify backup integrity regularly
- Plan for 2x capacity headroom for unexpected growth

----

## Related Documentation

- [deployment.md](deployment.md) - Deployment procedures
- [scaling.md](scaling.md) - Scaling operations that affect storage
- [elasticsearch.md](elasticsearch.md) - Elasticsearch component details
- [readme.md](readme.md) - Project overview
