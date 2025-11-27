# Scaling Guide

## Overview

This guide explains how to scale Elasticsearch and Logstash components. Kibana does not require scaling as it is a stateless UI component.

----

## Elasticsearch Scaling

#### Current Configuration

- Replicas: 1 (single-node mode)
- Storage: 50Gi per pod
- Discovery type: single-node

#### Scaling to Multi-Node Cluster

When scaling Elasticsearch from 1 to 3 nodes, the cluster transitions from single-node mode to a multi-node cluster with proper discovery and master election.

----

## Prepare for Elasticsearch Scaling

#### Create Additional Persistent Volumes

Create file `[storage/elasticsearch-pv-node-1.yaml]`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: elasticsearch-node-1-pv
  labels:
    type: local
    node-id: "1"
spec:
  storageClassName: elasticsearch-local-storage
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/ssd/elasticsearch/node-1
```

Create file `[storage/elasticsearch-pv-node-2.yaml]`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: elasticsearch-node-2-pv
  labels:
    type: local
    node-id: "2"
spec:
  storageClassName: elasticsearch-local-storage
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /mnt/ssd/elasticsearch/node-2
```

#### Create Storage Directories

Add to `[setup.sh]` script before running:

```bash
mkdir -p /host/mnt/ssd/elasticsearch/node-1
mkdir -p /host/mnt/ssd/elasticsearch/node-2
chown -R 1000:1000 /host/mnt/ssd/elasticsearch
```

#### Update Elasticsearch Configuration

Edit `[elasticsearch/elasticsearch-config.yaml]`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: elasticsearch-config
  namespace: k3s-elk
data:
  elasticsearch.yml: |
    cluster.name: k3s-elasticsearch-cluster
    network.host: 0.0.0.0
    discovery.seed_hosts: ["elasticsearch-0.elasticsearch-headless", "elasticsearch-1.elasticsearch-headless", "elasticsearch-2.elasticsearch-headless"]
    cluster.initial_master_nodes: ["elasticsearch-0", "elasticsearch-1", "elasticsearch-2"]
    xpack.security.enabled: false
    xpack.security.http.ssl.enabled: false
    path.data: /usr/share/elasticsearch/data
    path.logs: /usr/share/elasticsearch/logs
```

Remove discovery.type from environment variables in `[elasticsearch/elasticsearch-statefulset.yaml]`.

#### Update Replica Count

Edit `[elasticsearch/elasticsearch-statefulset.yaml]`:

```yaml
spec:
  replicas: 3
```

#### Apply Changes

```bash
kubectl apply -f storage/elasticsearch-pv-node-1.yaml
kubectl apply -f storage/elasticsearch-pv-node-2.yaml
kubectl apply -f elasticsearch/elasticsearch-config.yaml
kubectl apply -f elasticsearch/elasticsearch-statefulset.yaml
```

#### Verify Cluster Formation

```bash
kubectl get pods -n k3s-elk -l app=elasticsearch
kubectl exec -n k3s-elk elasticsearch-0 -- curl http://localhost:9200/_cluster/health?pretty
```

Expected output shows 3 nodes with green status.

----

## Logstash Scaling

#### Current Configuration

- Replicas: 1
- Storage: 10Gi per pod (for persistent queue)
- Memory: 512Mi request, 1Gi limit

#### Scaling Considerations

- Each replica processes logs independently
- Load balancer service distributes traffic across all replicas
- Each replica gets own 10Gi persistent queue storage
- Useful for high-volume log ingestion scenarios

----

## Scale Logstash Replicas

#### Using kubectl Command

Temporary scaling without modifying files:

```bash
kubectl scale statefulset logstash --replicas=2 -n k3s-elk
```

Scale to 3 replicas:

```bash
kubectl scale statefulset logstash --replicas=3 -n k3s-elk
```

#### Using Configuration File

Edit `[logstash/logstash-statefulset.yaml]`:

```yaml
spec:
  replicas: 3
```

Apply changes:

```bash
kubectl apply -f logstash/logstash-statefulset.yaml
```

Update `[deploy.sh]` wait condition:

```bash
kubectl wait statefulset/logstash \
  --for=jsonpath='{.status.readyReplicas}'=3 \
  --timeout=300s \
  -n k3s-elk
```

----

## Monitoring Scaling Operations

#### Watch Pod Creation

```bash
kubectl get pods -n k3s-elk -l app=logstash -w
```

Pods are created sequentially: logstash-0, then logstash-1, then logstash-2.

#### Check StatefulSet Status

```bash
kubectl describe statefulset logstash -n k3s-elk
kubectl describe statefulset elasticsearch -n k3s-elk
```

Look for Replicas, Ready Replicas, and Current Replicas fields.

#### Verify PVC Creation

```bash
kubectl get pvc -n k3s-elk
```

For 3 Logstash replicas expect:

- logstash-data-logstash-0 (10Gi, Bound)
- logstash-data-logstash-1 (10Gi, Bound)
- logstash-data-logstash-2 (10Gi, Bound)

For 3 Elasticsearch replicas expect:

- data-elasticsearch-0 (50Gi, Bound)
- data-elasticsearch-1 (50Gi, Bound)
- data-elasticsearch-2 (50Gi, Bound)

----

## Scaling Down

#### Logstash Scale Down

Scale down to 1 replica:

```bash
kubectl scale statefulset logstash --replicas=1 -n k3s-elk
```

Behavior:

- Pods logstash-2 and logstash-1 are terminated in reverse order
- PVCs remain bound and retain data
- Scaling back up reuses existing PVCs

#### Elasticsearch Scale Down

Not recommended for Elasticsearch as it requires cluster reconfiguration and data rebalancing.

If necessary:

- Verify cluster health is green before scaling down
- Scale down one node at a time
- Allow cluster to rebalance shards between scale operations
- Update discovery configuration to remove scaled-down nodes

----

## Persistent Volume Management

#### Automatic PVC Creation

StatefulSets automatically create PVCs using volumeClaimTemplates:

- PVC naming pattern: volumename-podname
- Created when pod is scheduled
- Bound to available PV matching StorageClass
- Not deleted when pod is deleted

#### Manual PVC Cleanup

After scaling down, remove orphaned PVCs:

```bash
kubectl delete pvc logstash-data-logstash-2 -n k3s-elk
kubectl delete pvc data-elasticsearch-2 -n k3s-elk
```

Warning: This permanently deletes data in the PVC.

#### View PVC Storage Location

For k3s local-path provisioner:

```bash
sudo ls -lah /var/lib/rancher/k3s/storage/
```

#### Check Storage Usage

```bash
kubectl exec -n k3s-elk logstash-0 -- df -h /usr/share/logstash/data
kubectl exec -n k3s-elk elasticsearch-0 -- df -h /usr/share/elasticsearch/data
```

----

## Resource Planning

#### Elasticsearch Resource Requirements

Per pod requirements:

- CPU: 500m request, 1 CPU limit
- Memory: 2Gi request and limit
- Storage: 50Gi persistent volume

For 3 replica cluster:

- Total CPU: 1.5 CPU request, 3 CPU limit
- Total Memory: 6Gi
- Total Storage: 150Gi

#### Logstash Resource Requirements

Per pod requirements:

- CPU: 200m request, 500m CPU limit
- Memory: 512Mi request, 1Gi limit
- Storage: 10Gi persistent volume

For 3 replica setup:

- Total CPU: 600m request, 1.5 CPU limit
- Total Memory: 1.5Gi request, 3Gi limit
- Total Storage: 30Gi

#### Node Capacity Verification

Check available resources:

```bash
kubectl describe node <node-name>
```

Review Allocatable resources and current Allocated resources sections.

----

## Load Distribution

#### Logstash Load Balancing

The logstash NodePort service distributes traffic using kube-proxy:

- Round-robin distribution across ready pods
- Connection-based load balancing
- No session affinity configured
- Traffic naturally balances with high volume

#### Elasticsearch Shard Distribution

With multiple Elasticsearch nodes:

- Primary shards distributed across nodes
- Replica shards placed on different nodes than primary
- Automatic rebalancing when nodes join or leave cluster
- Query load distributed across all nodes containing relevant shards

#### Verify Load Distribution

Send test traffic:

```bash
for i in {1..10}; do
  kubectl run test-$i --rm -it --image=busybox -n k3s-elk -- sh -c \
    "echo '{\"test\":\"$i\"}' | nc logstash.k3s-elk 5044"
done
```

Check which pods received messages:

```bash
kubectl logs logstash-0 -n k3s-elk --tail=20
kubectl logs logstash-1 -n k3s-elk --tail=20
kubectl logs logstash-2 -n k3s-elk --tail=20
```

----

## Troubleshooting Scaling Issues

#### Pod Stuck in Pending

Check PVC status:

```bash
kubectl describe pvc data-elasticsearch-1 -n k3s-elk
```

Common causes:

- No available PV matching requirements
- Insufficient storage on node
- StorageClass not found

#### Pod CrashLoopBackOff After Scaling

View logs:

```bash
kubectl logs elasticsearch-1 -n k3s-elk
kubectl logs logstash-1 -n k3s-elk
```

Common causes:

- Configuration errors in ConfigMap
- Insufficient memory or CPU
- Network connectivity issues between pods
- Storage permissions incorrect

#### Uneven Traffic Distribution

Verify service endpoints:

```bash
kubectl get endpoints logstash -n k3s-elk
```

All ready pods should be listed. If missing:

- Check pod readiness probes
- Verify pod labels match service selector

#### Scaling Takes Too Long

Check events:

```bash
kubectl get events -n k3s-elk --sort-by='.lastTimestamp'
```

Common delays:

- Image pull from registry
- PVC provisioning and binding
- Pod initialization and readiness probes

----

## Best Practices

- Start with 1 replica for development and testing
- Scale Elasticsearch to 3 nodes for production to enable high availability
- Scale Logstash based on log ingestion rate not arbitrarily
- Monitor resource usage before adding replicas
- Clean up unused PVCs after scaling down to reclaim storage
- Update configuration files for permanent scaling changes
- Test scaling operations in non-production environment first
- Document scaling decisions and capacity planning

----

## Related Documentation

- [deployment.md](deployment.md) - Initial deployment procedures
- [storage.md](storage.md) - Storage configuration details
- [elasticsearch.md](elasticsearch.md) - Elasticsearch component documentation
- [readme.md](readme.md) - Project overview
