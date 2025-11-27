# deployments

Kubernetes Deployment definitions for stateless ELK components.

----

## files

- `kibana-deployment.yaml` - Kibana web interface

----

## kibana deployment

#### key features

- Stateless application (UI layer only)
- RollingUpdate strategy with maxUnavailable: 0 for zero downtime
- Persistent storage for saved objects via PVC
- Connects to Elasticsearch via internal service
- External access via NodePort service (30561)

#### resources (development)

- CPU: 100m request, 200m limit
- Memory: 512Mi
- Storage: 5Gi (via PVC)
- Replicas: 1 (can scale to 2+ for load distribution)

----

## update strategy

Uses RollingUpdate with maxUnavailable: 0 and maxSurge: 1:

- New pod starts and becomes ready
- Old pod terminates after new pod is healthy
- Ensures continuous availability during updates

#### perform rolling update

```bash
kubectl set image deployment/elk-kibana kibana=docker.elastic.co/kibana/kibana:8.11.0 -n k3s-elk
kubectl rollout status deployment/elk-kibana -n k3s-elk
```

#### rollback if needed

```bash
kubectl rollout undo deployment/elk-kibana -n k3s-elk
```

----

## scaling

Kibana can be scaled for load distribution (sessions stored in Elasticsearch):

```bash
kubectl scale deployment elk-kibana --replicas=2 -n k3s-elk
```

Note: Single replica is sufficient for most use cases.

----

## related documentation

- [../docs/deployment.md](../docs/deployment.md) - initial deployment procedures
- [../docs/production-resources.md](../docs/production-resources.md) - resource planning
- [../docs/usage.md](../docs/usage.md) - using kibana for visualization
- [../readme.md](../readme.md) - project overview
