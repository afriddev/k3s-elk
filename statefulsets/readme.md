# statefulsets

Kubernetes StatefulSet definitions for stateful ELK components requiring stable network identities and persistent storage.

----

## files

- `elasticsearch-statefulset.yaml` - Elasticsearch cluster
- `logstash-statefulset.yaml` - Logstash data pipeline

----

## elasticsearch statefulset

#### key features

- Ordered pod creation and updates (elk-elasticsearch-0, -1, -2)
- Stable network identity via headless service
- Persistent storage via volumeClaimTemplates (20Gi per pod)
- RollingUpdate strategy for zero-downtime updates
- Init containers for system tuning (vm.max_map_count, file descriptors)

#### resources (development)

- CPU: 250m request, 500m limit
- Memory: 1Gi
- Storage: 20Gi per pod
- Replicas: 1 (scalable to 3+)

----

## logstash statefulset

#### key features

- Ordered pod creation and updates (elk-logstash-0, -1, -2)
- Stable network identity for log routing
- Persistent queue storage via volumeClaimTemplates (10Gi per pod)
- RollingUpdate strategy for zero-downtime updates
- ConfigMap mount for pipeline configuration

#### resources (development)

- CPU: 100m request, 200m limit
- Memory: 512Mi
- Storage: 10Gi per pod
- Replicas: 1 (scalable to 2+)

----

## update strategy

Both StatefulSets use RollingUpdate with OrderedReady pod management:

- Updates happen one pod at a time in reverse order
- Pod must be ready before next pod updates
- Ensures zero downtime during updates

#### perform rolling update

```bash
kubectl set image statefulset/elk-elasticsearch elasticsearch=docker.elastic.co/elasticsearch/elasticsearch:8.11.0 -n k3s-elk
kubectl rollout status statefulset/elk-elasticsearch -n k3s-elk
```

#### rollback if needed

```bash
kubectl rollout undo statefulset/elk-elasticsearch -n k3s-elk
```

----

## scaling

#### scale elasticsearch

```bash
kubectl scale statefulset elk-elasticsearch --replicas=3 -n k3s-elk
```

Create additional PVs before scaling (see [../storage/readme.md](../storage/readme.md))

#### scale logstash

```bash
kubectl scale statefulset elk-logstash --replicas=2 -n k3s-elk
```

PVCs are automatically created via volumeClaimTemplates.

----

## related documentation

- [../docs/scaling.md](../docs/scaling.md) - detailed scaling procedures
- [../docs/production-resources.md](../docs/production-resources.md) - resource planning and upgrades
- [../docs/deployment.md](../docs/deployment.md) - initial deployment
- [../readme.md](../readme.md) - project overview
