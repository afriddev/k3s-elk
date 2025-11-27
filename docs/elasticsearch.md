# Elasticsearch Documentation

## Overview

Elasticsearch serves as the core data storage and search engine for the ELK stack. This component indexes and stores all log data, providing fast search and analytics capabilities.

----

## Component Details

#### Version
- docker.elastic.co/elasticsearch/elasticsearch:8.10.2

#### Deployment Type
- StatefulSet with persistent storage

#### Default Configuration
- Replicas: 1 (single-node mode)
- Storage: 50Gi persistent volume per pod
- Memory: 2Gi allocated per pod
- CPU: 500m request, 1 CPU limit

----

## Architecture

#### Storage Strategy
- Uses volumeClaimTemplates for automatic PVC creation
- StorageClass: elasticsearch-local-storage
- Host path: /mnt/ssd/elasticsearch/node-N
- Reclaim policy: Retain

#### Network Services
- elasticsearch-headless: ClusterIP None for StatefulSet pod discovery
- elasticsearch-external: NodePort 30920 for external access

#### Pod Identity
- Predictable naming: elasticsearch-0, elasticsearch-1, elasticsearch-2
- Stable network identity via headless service
- Ordered pod creation and termination

----

## Files Reference

#### Configuration Files
- `[elasticsearch/elasticsearch-config.yaml]` - ConfigMap with elasticsearch.yml configuration
- `[elasticsearch/elasticsearch-statefulset.yaml]` - StatefulSet definition with resource limits
- `[elasticsearch/elasticsearch-service-headless.yaml]` - Headless service for cluster communication
- `[elasticsearch/elasticsearch-service-nodeport.yaml]` - NodePort service for external access

#### Storage Files
- `[storage/elasticsearch-storage-class.yaml]` - StorageClass configuration
- `[storage/elasticsearch-pv-node-0.yaml]` - PersistentVolume for first node

----

## Access Endpoints

#### Internal Cluster Access
```
http://elasticsearch-0.elasticsearch-headless.k3s-elk.svc.cluster.local:9200
```

#### External Access
```
http://<node-ip>:30920
```

#### Transport Communication
```
elasticsearch-0.elasticsearch-headless.k3s-elk.svc.cluster.local:9300
```

----

## Health Monitoring

#### Cluster Health Check
```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_cluster/health?pretty
```

#### Expected Response
```json
{
  "cluster_name": "k3s-elasticsearch-cluster",
  "status": "green",
  "number_of_nodes": 1,
  "number_of_data_nodes": 1
}
```

#### Node Information
```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_nodes/stats?pretty
```

----

## Index Management

#### List All Indices
```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_cat/indices?v
```

#### View Index Settings
```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/<index-name>/_settings?pretty
```

#### Delete Index
```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XDELETE http://localhost:9200/<index-name>
```

----

## Data Operations

#### Create Index
```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XPUT http://localhost:9200/my-index -H 'Content-Type: application/json' -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  }
}'
```

#### Insert Document
```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XPOST http://localhost:9200/my-index/_doc -H 'Content-Type: application/json' -d '{
  "field": "value",
  "timestamp": "2024-01-01T00:00:00Z"
}'
```

#### Search Documents
```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/my-index/_search?pretty
```

----

## Storage Configuration

#### Persistent Volume Claim
- Automatically created via volumeClaimTemplates
- Naming pattern: data-elasticsearch-N
- Size: 50Gi per pod
- Access mode: ReadWriteOnce

#### Host Path Setup
Created by `[setup.sh]` script:
```
/mnt/ssd/elasticsearch/
└── node-0/
```

#### Storage Expansion
To increase storage for existing node:
- Cannot modify volumeClaimTemplates directly
- Requires StatefulSet recreation with data migration
- Plan storage requirements in advance

----

## Troubleshooting

#### Pod Not Starting
```bash
kubectl describe pod elasticsearch-0 -n k3s-elk
kubectl logs elasticsearch-0 -n k3s-elk
```

Common issues:
- Insufficient memory on node
- PVC not bound to PV
- Host path permissions incorrect
- vm.max_map_count not set (handled by init container)

#### PVC Stuck Pending
```bash
kubectl describe pvc data-elasticsearch-0 -n k3s-elk
```

Verify:
- PV exists and matches StorageClass
- Host directory /mnt/ssd/elasticsearch/node-0 exists
- Sufficient disk space available

#### Performance Issues
```bash
kubectl top pod elasticsearch-0 -n k3s-elk
```

Check:
- Memory usage approaching limits
- CPU throttling occurring
- Disk I/O bottlenecks

----

## Security Configuration

#### Current Settings
- xpack.security.enabled: false
- xpack.security.http.ssl.enabled: false
- No authentication required

#### Production Recommendations
- Enable xpack security features
- Configure SSL/TLS encryption
- Implement role-based access control
- Use secrets for credentials

----

## Backup and Restore

#### Manual Data Backup
```bash
kubectl scale statefulset elasticsearch --replicas=0 -n k3s-elk
sudo tar -czf elasticsearch-backup-$(date +%Y%m%d).tar.gz /mnt/ssd/elasticsearch
kubectl scale statefulset elasticsearch --replicas=1 -n k3s-elk
```

#### Snapshot API
Configure snapshot repository for automated backups:
```bash
curl -XPUT http://<node-ip>:30920/_snapshot/my_backup -H 'Content-Type: application/json' -d '{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/backups"
  }
}'
```

----

## Related Documentation

- [scaling.md](scaling.md) - Elasticsearch scaling procedures
- [storage.md](storage.md) - Persistent storage configuration
- [deployment.md](deployment.md) - Complete deployment guide
- [readme.md](readme.md) - Project overview
