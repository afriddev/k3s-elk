# ELK Stack Deployment Guide

## Overview

This guide provides complete instructions for deploying the ELK stack on Kubernetes. The deployment includes Elasticsearch for data storage, Logstash for log processing, and Kibana for visualization.

----

## Prerequisites

#### Kubernetes Cluster Requirements

- K3s or Kubernetes cluster version 1.24 or higher
- kubectl CLI tool configured with cluster access
- Node with minimum 8GB RAM and 2 vCPUs
- Host storage path /mnt/ssd available with sufficient disk space

#### Software Requirements

- kubectl CLI tool installed and configured
- bash shell for running deployment scripts
- curl for testing endpoints

#### Network Requirements

- NodePort range 30000-32767 available
- Required ports: 30920 (Elasticsearch), 30561 (Kibana), 30044 (Logstash)

----

## Deployment Process

#### Clone or Download Repository

Ensure you have all project files in your working directory.

#### Run Storage Setup Script

Execute the setup script to create required host directories:

```bash
bash setup.sh
```

This script performs the following operations:

- Detects your kubernetes node name automatically
- Creates /mnt/ssd/elasticsearch/node-0 directory for Elasticsearch data
- Creates /mnt/ssd/kibana-data directory for Kibana saved objects
- Sets proper permissions and ownership for Elasticsearch (UID 1000)
- Sets permissions for Kibana data directory

#### Execute Deployment Script

Deploy all ELK components using the automated script:

```bash
bash deploy.sh
```

The deployment script executes these operations in sequence:

- Creates k3s-elk namespace
- Applies storage resources (StorageClass, PVs, PVCs)
- Deploys Elasticsearch configuration and services
- Deploys Elasticsearch StatefulSet
- Deploys Logstash configuration and services
- Deploys Logstash StatefulSet
- Deploys Kibana deployment and service
- Waits for all components to reach ready state

----

## Verification

#### Check Pod Status

Verify all pods are running:

```bash
kubectl get pods -n k3s-elk
```

Expected output shows all pods in Running state with 1/1 ready:

```
NAME              READY   STATUS    RESTARTS   AGE
elasticsearch-0   1/1     Running   0          5m
logstash-0        1/1     Running   0          4m
kibana-xxx        1/1     Running   0          3m
```

#### Check Service Status

Verify all services are created:

```bash
kubectl get svc -n k3s-elk
```

Expected services:

- elasticsearch-headless (ClusterIP None)
- elasticsearch-external (NodePort 30920)
- logstash-headless (ClusterIP None)
- logstash (NodePort 30044)
- kibana (NodePort 30561)

#### Check Storage Status

Verify persistent volumes and claims:

```bash
kubectl get pv
kubectl get pvc -n k3s-elk
```

All PVCs should show Bound status.

#### Test Elasticsearch

Verify Elasticsearch cluster health:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_cluster/health?pretty
```

Expected status: green with 1 node available.

#### Test Kibana Access

Access Kibana web interface:

```
http://<node-ip>:30561
```

Replace node-ip with your Kubernetes node IP address.

----

## Component Configuration

#### Elasticsearch Configuration

Configuration file: `[elasticsearch/elasticsearch-config.yaml]`

Key settings:

- cluster.name: k3s-elasticsearch-cluster
- discovery.type: single-node
- xpack.security.enabled: false
- network.host: 0.0.0.0

#### Logstash Configuration

Configuration file: `[logstash/logstash-config.yaml]`

Pipeline configuration:

- Input: TCP port 5044 with JSON lines codec
- Filter: JSON parsing for message field
- Output: Elasticsearch with daily index pattern logs-YYYY.MM.dd

#### Kibana Configuration

Environment variables in `[kibana/kibana-deployment.yaml]`:

- ELASTICSEARCH_HOSTS: Points to elasticsearch-0.elasticsearch-headless.k3s-elk.svc.cluster.local:9200
- SERVER_HOST: 0.0.0.0
- SERVER_NAME: kibana

----

## Post-Deployment Configuration

#### Configure Kibana Index Pattern

- Navigate to http://node-ip:30561
- Go to Management menu
- Select Stack Management
- Select Index Patterns under Kibana section
- Click Create index pattern
- Enter pattern: logs-*
- Click Next step
- Select @timestamp as Time field
- Click Create index pattern

#### Send Test Log

Verify log ingestion pipeline:

```bash
kubectl run test-logger --rm -it --image=busybox -n k3s-elk -- sh -c \
  'echo "{\"message\":\"Test log entry\",\"level\":\"info\",\"service\":\"test\"}" | nc logstash.k3s-elk 5044'
```

#### View Test Log in Kibana

- Navigate to Discover section in Kibana
- Select logs-* index pattern
- Verify test log appears in results

----

## Access Configuration

#### External Access Endpoints

- Elasticsearch API: http://node-ip:30920
- Kibana Web UI: http://node-ip:30561
- Logstash TCP Input: node-ip:30044

#### Internal Cluster Endpoints

- Elasticsearch: elasticsearch-0.elasticsearch-headless.k3s-elk.svc.cluster.local:9200
- Logstash: logstash.k3s-elk.svc.cluster.local:5044

#### Service Type Configuration

All external services use NodePort type. To change to LoadBalancer or ClusterIP:

- Edit respective service YAML files
- Change spec.type value
- Reapply configuration with kubectl apply

----

## Troubleshooting

#### Pods Stuck in Pending

Check events for the pod:

```bash
kubectl describe pod <pod-name> -n k3s-elk
```

Common causes:

- Insufficient resources on node
- PVC not binding to PV
- Node selector or affinity rules not satisfied

#### PVC Not Binding

Check PVC status:

```bash
kubectl describe pvc <pvc-name> -n k3s-elk
```

Common causes:

- PV not created or already bound
- StorageClass not found
- Access mode mismatch
- Capacity not satisfied

#### Elasticsearch Pod CrashLoopBackOff

View pod logs:

```bash
kubectl logs elasticsearch-0 -n k3s-elk
```

Common causes:

- Insufficient memory
- vm.max_map_count not set (should be handled by init container)
- Storage permissions incorrect
- Corrupted data in persistent volume

#### Logstash Not Receiving Logs

Check Logstash pod logs:

```bash
kubectl logs logstash-0 -n k3s-elk
```

Verify service endpoints:

```bash
kubectl get endpoints -n k3s-elk
```

Test connectivity from test pod:

```bash
kubectl run test-nc --rm -it --image=busybox -n k3s-elk -- nc -zv logstash.k3s-elk 5044
```

#### Kibana Cannot Connect to Elasticsearch

Check Kibana pod logs:

```bash
kubectl logs -n k3s-elk deployment/kibana
```

Verify Elasticsearch is accessible:

```bash
kubectl run test-curl --rm -it --image=curlimages/curl -n k3s-elk -- \
  curl http://elasticsearch-0.elasticsearch-headless.k3s-elk.svc.cluster.local:9200
```

----

## Security Considerations

#### Current Configuration

- No authentication enabled on any component
- No SSL/TLS encryption configured
- All services accessible without credentials
- Suitable for development and testing environments

#### Production Recommendations

- Enable Elasticsearch xpack security features
- Configure SSL/TLS certificates for all components
- Implement Kubernetes Network Policies
- Use Kubernetes Secrets for sensitive configuration
- Enable RBAC for Kibana access
- Restrict NodePort access via firewall rules

----

## Monitoring

#### Pod Resource Usage

```bash
kubectl top pods -n k3s-elk
```

#### Storage Usage

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- df -h /usr/share/elasticsearch/data
kubectl exec -n k3s-elk logstash-0 -- df -h /usr/share/logstash/data
kubectl exec -n k3s-elk deployment/kibana -- df -h /usr/share/kibana/data
```

#### Component Health

Elasticsearch:
```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl http://localhost:9200/_cluster/health
```

Kibana:
```bash
kubectl exec -n k3s-elk deployment/kibana -- curl http://localhost:5601/api/status
```

----

## Updating Configuration

#### Modify Elasticsearch Configuration

- Edit `[elasticsearch/elasticsearch-config.yaml]`
- Apply changes: kubectl apply -f elasticsearch/elasticsearch-config.yaml
- Restart pods: kubectl rollout restart statefulset/elasticsearch -n k3s-elk

#### Modify Logstash Pipeline

- Edit `[logstash/logstash-config.yaml]`
- Apply changes: kubectl apply -f logstash/logstash-config.yaml
- Restart pods: kubectl rollout restart statefulset/logstash -n k3s-elk

#### Modify Resource Limits

- Edit respective StatefulSet or Deployment YAML files
- Apply changes with kubectl apply
- Pods will be recreated with new resource limits

----

## Backup Procedures

#### Elasticsearch Data Backup

```bash
kubectl scale statefulset elasticsearch --replicas=0 -n k3s-elk
sudo tar -czf elasticsearch-backup-$(date +%Y%m%d).tar.gz /mnt/ssd/elasticsearch
kubectl scale statefulset elasticsearch --replicas=1 -n k3s-elk
```

#### Kibana Data Backup

```bash
kubectl scale deployment kibana --replicas=0 -n k3s-elk
sudo tar -czf kibana-backup-$(date +%Y%m%d).tar.gz /mnt/ssd/kibana-data
kubectl scale deployment kibana --replicas=1 -n k3s-elk
```

----

## Related Documentation

- `[README.md]` - Project overview and quick start
- [elasticsearch.md](elasticsearch.md) - Elasticsearch component details
- [scaling.md](scaling.md) - Scaling procedures
- [storage.md](storage.md) - Storage configuration
- [usage.md](usage.md) - Usage examples and integration
