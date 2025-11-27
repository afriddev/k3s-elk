## ELK Stack Persistent Storage Configuration

## Overview

This document explains the persistent storage configuration for the ELK Stack. Data is stored on the host to ensure it survives pod restarts, node failures, and cluster deletions.

## Storage Architecture

#### Persistent Storage Layers

The storage system consists of three layers

- Host Directories at /mnt/ssd provide physical storage on the k3s node
  - Created by setup.sh script
  - Survives cluster deletion and pod restarts
  - Data persists even when Kubernetes is removed

- PersistentVolumes provide Kubernetes abstraction of host storage
  - Uses hostPath type pointing to /mnt/ssd
  - Reclaim policy set to Retain prevents automatic data deletion
  - Cluster-wide resources not namespace-scoped

- PersistentVolumeClaims request storage for applications
  - Bound to specific PVs using label selectors
  - Mounted into application pods
  - Namespace-scoped resources

## Storage Components

#### Logstash Storage

Logstash uses StatefulSet with dynamic persistent volume provisioning

- Deployment Type is StatefulSet with 2 replicas
- Storage Method uses volumeClaimTemplates
- Capacity is 10Gi per pod
- Mount Point is /usr/share/logstash/data

What gets stored
- Dead letter queue for failed events
- Persistent queue data
- Pipeline state and checkpoints

Each Logstash pod gets its own PVC automatically created
- logstash-data-logstash-0
- logstash-data-logstash-1

#### Kibana Storage

Kibana uses traditional PV and PVC binding

- Host Path is /mnt/ssd/kibana-data
- PV Name is kibana-data-pv
- PVC Name is kibana-data-pvc
- Capacity is 5Gi
- Mount Point is /usr/share/kibana/data

What gets stored
- Saved searches
- Visualizations
- Dashboards
- Index patterns
- User preferences

## Deployment Process

#### Setup Storage

Run the setup script once before first deployment

```bash
bash setup.sh
```

This creates host directories

```
/mnt/ssd/
└── kibana-data/
```

Logstash storage is created automatically by StatefulSet

#### Deploy Storage Resources

The deploy.sh script automatically applies storage manifests

```bash
kubectl apply -f storage/
```

Order of operations
- PersistentVolumes created at cluster level
- PersistentVolumeClaims created in namespace
- PVCs bind to PVs using label selectors
- Applications deploy and mount PVCs

## Storage Files

```
storage/
├── kibana-pv.yaml
└── kibana-pvc.yaml
```

Logstash storage is defined in logstash/logstash-statefulset.yaml using volumeClaimTemplates

## Data Persistence Guarantees

#### What Survives

The following events do not cause data loss
- Pod restart
- Pod deletion
- Node restart  
- Cluster deletion with data in /mnt/ssd
- Deployment updates
- StatefulSet scaling

#### What Causes Data Loss

The following events cause data loss
- Manual deletion of /mnt/ssd directories
- Node disk failure without backup strategy
- Intentional PV deletion

## Verification

#### Check PVs and PVCs

```bash
kubectl get pv

kubectl get pvc -n k3s-elk-stack

kubectl describe pvc kibana-data-pvc -n k3s-elk-stack

kubectl describe pvc logstash-data-logstash-0 -n k3s-elk-stack
kubectl describe pvc logstash-data-logstash-1 -n k3s-elk-stack
```

#### Check Host Directories

```bash
ls -lah /mnt/ssd/kibana-data

df -h /mnt/ssd
```

#### Check Pod Volume Mounts

```bash
kubectl exec -n k3s-elk-stack logstash-0 -- df -h /usr/share/logstash/data

kubectl exec -n k3s-elk-stack logstash-1 -- df -h /usr/share/logstash/data

kubectl exec -n k3s-elk-stack deployment/kibana -- df -h /usr/share/kibana/data
```

## Storage Sizing

Current allocations are conservative and can be adjusted based on usage

Component allocations
- Logstash has 10Gi per pod with low usage pattern
  - Stores queue only not data storage
  - Monitor queue depth over time
  - Can increase if deep queuing is needed

- Kibana has 5Gi total with very low usage pattern  
  - Stores metadata only
  - Sufficient for most use cases
  - Rarely needs expansion

Note that actual log data is stored in Elasticsearch not in this stack

## Troubleshooting

#### PVC Stuck in Pending

```bash
kubectl describe pvc pvc-name -n k3s-elk-stack
```

Common causes include
- PV not created
- Label selector mismatch
- Storage class not found
- Host directory does not exist

#### Pod Won't Start Due to Volume Mount Issue

```bash
kubectl describe pod pod-name -n k3s-elk-stack
```

Common causes include
- PVC not bound
- Incorrect mount path
- Permission issues on host directory

#### Permission Denied Errors

```bash
sudo chmod -R 777 /mnt/ssd/kibana-data
```

## Backup Strategy

#### Manual Backup

```bash
sudo tar -czf kibana-backup-$(date +%Y%m%d).tar.gz /mnt/ssd/kibana-data
```

#### Restore from Backup

```bash
kubectl scale deployment/kibana --replicas=0 -n k3s-elk-stack

sudo tar -xzf kibana-backup-YYYYMMDD.tar.gz -C /

kubectl scale deployment/kibana --replicas=1 -n k3s-elk-stack
```

#### Logstash Backup

Logstash queue data backup is typically not needed as it is transient data

If needed, backup individual pod PVCs

```bash
kubectl scale statefulset/logstash --replicas=0 -n k3s-elk-stack

# Backup data from k3s local-path provisioner
# Default location is /var/lib/rancher/k3s/storage
sudo tar -czf logstash-pvcs-$(date +%Y%m%d).tar.gz /var/lib/rancher/k3s/storage

kubectl scale statefulset/logstash --replicas=2 -n k3s-elk-stack
```

## Migration Notes

#### Moving to New Node

Steps for migration
- Backup data from old node
- Setup storage on new node using bash setup.sh
- Restore data to /mnt/ssd on new node
- Deploy ELK stack

#### Increasing Storage

For Kibana with hostPath
- No need to modify PV or PVC sizes
- Ensure /mnt/ssd has sufficient disk space
- Check with df -h /mnt/ssd

For Logstash StatefulSet
- Edit StatefulSet volumeClaimTemplates
- Delete and recreate StatefulSet
- Data migration may be required

## Best Practices

Storage management recommendations
- Schedule regular backups of /mnt/ssd
- Monitor disk usage and alert when exceeding 80 percent
- Implement log retention policy in Elasticsearch
- Test backup restoration periodically
- Document any storage modifications in this file
- Review capacity quarterly

## Related Documentation

- Deployment Guide in docs/README.md
- Kubernetes Persistent Volumes documentation
