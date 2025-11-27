# production resources

## overview

This document provides resource configurations for development and production environments. Current deployment uses development settings optimized for testing and local development.

----

## development configuration (current)

#### elasticsearch

- CPU Request: 250m
- CPU Limit: 500m
- Memory Request: 1Gi
- Memory Limit: 1Gi
- Storage: 20Gi per pod
- Java Heap: 512MB

#### logstash

- CPU Request: 100m
- CPU Limit: 200m
- Memory Request: 512Mi
- Memory Limit: 512Mi
- Storage: 10Gi per pod
- Java Heap: 256MB

#### kibana

- CPU Request: 100m
- CPU Limit: 200m
- Memory Request: 512Mi
- Memory Limit: 512Mi
- Storage: 5Gi

#### total development resources

- CPU: 450m request, 900m limit
- Memory: 2Gi request, 2Gi limit
- Storage: 35Gi total

----

## production configuration (recommended)

#### elasticsearch

- CPU Request: 1000m (1 CPU)
- CPU Limit: 2000m (2 CPU)
- Memory Request: 4Gi
- Memory Limit: 4Gi
- Storage: 100Gi per pod
- Java Heap: 2GB
- Replicas: 3 (minimum for HA)

#### logstash

- CPU Request: 500m
- CPU Limit: 1000m (1 CPU)
- Memory Request: 2Gi
- Memory Limit: 2Gi
- Storage: 20Gi per pod
- Java Heap: 1GB
- Replicas: 2 (minimum for HA)

#### kibana

- CPU Request: 500m
- CPU Limit: 1000m (1 CPU)
- Memory Request: 2Gi
- Memory Limit: 2Gi
- Storage: 10Gi
- Replicas: 1 (can remain 1)

#### total production resources (3 ES + 2 LS + 1 KB)

- CPU: 5500m request, 11000m limit
- Memory: 18Gi request, 18Gi limit
- Storage: 350Gi total

----

## upgrading to production

#### update elasticsearch resources

Edit `statefulsets/elasticsearch-statefulset.yaml`:

```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"

env:
- name: ES_JAVA_OPTS
  value: "-Xms2g -Xmx2g"

volumeClaimTemplates:
- metadata:
    name: data
  spec:
    resources:
      requests:
        storage: 100Gi
```

#### update logstash resources

Edit `statefulsets/logstash-statefulset.yaml`:

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"

env:
- name: LS_JAVA_OPTS
  value: "-Xms1g -Xmx1g"

volumeClaimTemplates:
- metadata:
    name: logstash-data
  spec:
    resources:
      requests:
        storage: 20Gi
```

#### update kibana resources

Edit `deployments/kibana-deployment.yaml`:

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

Update `storage/pvc/kibana-pvc.yaml`:

```yaml
resources:
  requests:
    storage: 10Gi
```

----

## scaling for production

#### scale elasticsearch to 3 nodes

```bash
kubectl scale statefulset elk-elasticsearch --replicas=3 -n k3s-elk
```

Before scaling, create additional PVs for nodes 1 and 2. Copy `storage/pv/elasticsearch-node-0-pv.yaml` and modify for node-1 and node-2 with 100Gi storage.

Update Elasticsearch configuration for multi-node cluster in `configmaps/elasticsearch-config.yaml`:

```yaml
data:
  elasticsearch.yml: |
    cluster.name: k3s-elasticsearch-cluster
    network.host: 0.0.0.0
    discovery.seed_hosts: ["elk-elasticsearch-0.elk-elasticsearch-headless", "elk-elasticsearch-1.elk-elasticsearch-headless", "elk-elasticsearch-2.elk-elasticsearch-headless"]
    cluster.initial_master_nodes: ["elk-elasticsearch-0", "elk-elasticsearch-1", "elk-elasticsearch-2"]
    xpack.security.enabled: false
    path.data: /usr/share/elasticsearch/data
    path.logs: /usr/share/elasticsearch/logs
```

#### scale logstash to 2 replicas

```bash
kubectl scale statefulset elk-logstash --replicas=2 -n k3s-elk
```

Logstash PVCs are created automatically via volumeClaimTemplates.

----

## storage planning

#### elasticsearch storage growth

- Log retention: 30 days recommended
- Daily index size: Calculate based on log volume
- Example: 10GB/day × 30 days = 300GB minimum
- Add 20-30 percent buffer for overhead
- Total per node with 3 replicas: 100GB recommended

#### logstash storage

- Queue storage only (transient data)
- 20Gi sufficient for production with persistent queues
- Monitor queue depth and adjust if needed

#### kibana storage

- Saved objects, dashboards, visualizations
- Growth is minimal
- 10Gi sufficient for most production use cases

----

## monitoring resource usage

#### check current usage

```bash
kubectl top pods -n k3s-elk
kubectl top nodes
```

#### check storage usage

```bash
kubectl exec -n k3s-elk elk-elasticsearch-0 -- df -h /usr/share/elasticsearch/data
kubectl exec -n k3s-elk elk-logstash-0 -- df -h /usr/share/logstash/data
```

#### elasticsearch index sizes

```bash
kubectl exec -n k3s-elk elk-elasticsearch-0 -- curl http://localhost:9200/_cat/indices?v&h=index,store.size&s=store.size:desc
```

----

## resource optimization tips

#### development environment

- Use current settings for local testing
- Single replica for all components
- Reduce storage to minimum needed
- Lower memory limits to fit on laptop/desktop

#### staging environment

- Use 50 percent of production resources
- Single replica with production resource limits
- Test with production-like data volume

#### production environment

- Use recommended production settings
- Multiple replicas for high availability
- Plan storage based on retention policy
- Monitor and adjust based on actual usage

----

## update strategies explained

#### statefulset rolling updates

- updateStrategy: RollingUpdate ensures zero downtime
- podManagementPolicy: OrderedReady updates one pod at a time
- partition: 0 updates all pods (can be used for canary deployments)

Pods update in reverse order (highest ordinal first):

- elk-elasticsearch-2 updates first
- After ready, elk-elasticsearch-1 updates
- After ready, elk-elasticsearch-0 updates

#### deployment rolling updates

- strategy: RollingUpdate with maxUnavailable: 0 ensures zero downtime
- maxSurge: 1 allows one extra pod during update
- New pod starts, becomes ready, then old pod terminates

----

## performing updates

#### update elasticsearch version

Edit `statefulsets/elasticsearch-statefulset.yaml`:

```yaml
containers:
- name: elasticsearch
  image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
```

Apply changes:

```bash
kubectl apply -f statefulsets/elasticsearch-statefulset.yaml
```

Monitor rollout:

```bash
kubectl rollout status statefulset/elk-elasticsearch -n k3s-elk
kubectl get pods -n k3s-elk -w
```

#### update configuration

Edit ConfigMap:

```bash
kubectl edit configmap elk-elasticsearch-config -n k3s-elk
```

Restart pods to apply (rolling restart):

```bash
kubectl rollout restart statefulset/elk-elasticsearch -n k3s-elk
```

#### rollback failed update

```bash
kubectl rollout undo statefulset/elk-elasticsearch -n k3s-elk
kubectl rollout undo deployment/elk-kibana -n k3s-elk
```

----

## high availability considerations

#### elasticsearch

- Minimum 3 nodes for quorum
- Distribute across availability zones if possible
- Set index replicas based on node count
- Use node affinity/anti-affinity for pod distribution

#### logstash

- Minimum 2 replicas for availability
- Load balanced via service
- Persistent queues prevent data loss during restarts

#### kibana

- Single replica sufficient (stateless application)
- Can scale to 2 replicas for load distribution
- Sessions stored in Elasticsearch (not in-memory)

----

## node capacity planning

#### development node

- 4 vCPUs minimum
- 8GB RAM minimum
- 50GB storage minimum

#### production nodes (per node for 3-node cluster)

- 8 vCPUs minimum
- 24GB RAM minimum
- 150GB storage minimum

----

## troubleshooting resource issues

#### pods evicted or OOMKilled

Increase memory limits in respective YAML files and redeploy.

#### CPU throttling

Check metrics:

```bash
kubectl top pods -n k3s-elk
```

Increase CPU limits if sustained high usage.

#### storage full

Delete old indices:

```bash
kubectl exec -n k3s-elk elk-elasticsearch-0 -- curl -XDELETE http://localhost:9200/logs-2024.01.*
```

Implement index lifecycle management for automatic cleanup.

----

## related documentation

- [scaling.md](scaling.md) - Scaling procedures
- [storage.md](storage.md) - Storage architecture
- [deployment.md](deployment.md) - Deployment procedures
- [readme.md](../readme.md) - Project overview
