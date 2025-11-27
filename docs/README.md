## ELK Stack Deployment Guide

## Overview

This project provides a production-ready ELK stack for centralized logging on Kubernetes. The system includes Logstash with high availability, Kibana for visualization, and integrates with k3s-elasticsearch for data persistence.

## Components

- Logstash 8.10.2 for log ingestion and processing with HA
- Kibana 8.10.2 for log exploration and visualization
- Integration with k3s-elasticsearch for data storage

## Prerequisites

#### k3s-elasticsearch Cluster

The k3s-elasticsearch cluster must be deployed and running before deploying this stack

Verify it is running

```bash
kubectl get pods -n k3s-elasticsearch
kubectl exec -n k3s-elasticsearch k3s-elasticsearch-0 -- curl -XGET http://localhost:9200/_cluster/health
```

#### Kubernetes Cluster Requirements

- K3s or any Kubernetes cluster version 1.24 or higher
- kubectl configured with cluster access
- Node with at least 4GB RAM and 2 vCPUs
- Host storage at /mnt/ssd for persistent data

#### Software Requirements

- kubectl CLI tool
- bash shell for running deployment scripts

## Architecture

#### Namespace

All components deploy to the k3s-elk-stack namespace

#### Data Flow

The logging pipeline works as follows

- Applications send JSON logs to Logstash on port 5044
- Logstash processes and forwards logs to k3s-elasticsearch
- Kibana queries k3s-elasticsearch for visualization

#### Services

Service endpoints

- Logstash headless service for pod identity
- Logstash load balancer service on port 5044 for log ingestion
- Kibana NodePort on port 30561 for web UI access

#### High Availability

Logstash runs as StatefulSet with 2 replicas

- Each pod has independent persistent storage
- Load balancer distributes incoming log traffic
- Ensures continuous log collection during pod failures
- Automatic pod recovery maintains replica count

## Directory Structure

```
k3s-elk-stack/
├── namespace/
│   └── namespace.yaml
├── storage/
│   ├── kibana-pv.yaml
│   └── kibana-pvc.yaml
├── logstash/
│   ├── logstash-config.yaml
│   └── logstash-statefulset.yaml
├── kibana/
│   └── kibana-deployment.yaml
├── setup.sh
├── deploy.sh
└── docs/
    ├── README.md
    └── STORAGE.md
```

## Installation

#### Setup Storage

Create required storage directories on the host

```bash
bash setup.sh
```

This creates /mnt/ssd/kibana-data for persistent storage

Logstash storage is created automatically by StatefulSet

#### Deploy ELK Stack

Run the automated deployment script

```bash
bash deploy.sh
```

The script performs the following steps

- Creates k3s-elk-stack namespace
- Creates persistent volumes and claims
- Deploys Logstash StatefulSet with 2 replicas
- Deploys Kibana Deployment
- Waits for all pods to be ready

#### Verify Deployment

Check pod status

```bash
kubectl get pods -n k3s-elk-stack
```

Expected output shows 2 Logstash pods and 1 Kibana pod running

```
NAME         READY   STATUS    RESTARTS   AGE
logstash-0   1/1     Running   0          2m
logstash-1   1/1     Running   0          2m
kibana-xxx   1/1     Running   0          2m
```

Check services

```bash
kubectl get svc -n k3s-elk-stack
```

Check StatefulSet status

```bash
kubectl get statefulset -n k3s-elk-stack
```

Check persistent volumes

```bash
kubectl get pv
kubectl get pvc -n k3s-elk-stack
```

## Configuration

#### Logstash

Logstash is configured to

- Accept JSON logs on TCP port 5044
- Parse JSON messages automatically
- Forward to k3s-elasticsearch with daily indices in format logs-YYYY.MM.dd
- Run with 512MB to 1GB memory allocation
- Use persistent queue for data durability

Configuration file location

- Pipeline config in logstash/logstash-config.yaml
- StatefulSet definition in logstash/logstash-statefulset.yaml

#### Kibana

Kibana is pre-configured to connect to k3s-elasticsearch

Default settings

- Single replica deployment
- Memory allocation of 512MB to 1GB
- Persistent storage for saved objects
- Readiness probe on /api/status endpoint

## Accessing Services

#### Kibana

Access Kibana web interface via NodePort

```
http://node-ip:30561
```

Replace node-ip with your k3s node IP address

Initial setup steps

- Go to Management then Index Patterns
- Create index pattern matching logs-*
- Select @timestamp as time field
- Navigate to Discover to view logs

#### Logstash

Internal access from within the cluster

Using load balancer service for log ingestion

```
logstash-lb.k3s-elk-stack.svc.cluster.local:5044
```

For external applications configure your log shipper with this endpoint

Example Filebeat configuration

```yaml
output.logstash:
  hosts: ["logstash-lb.k3s-elk-stack:5044"]
  loadbalance: true
```

## Testing

#### Send Test Log

From within the cluster send a test message

```bash
kubectl run test-logger --rm -it --image=busybox -- sh -c "echo '{\"message\":\"Test log entry\",\"level\":\"info\",\"timestamp\":\"2024-01-01T00:00:00Z\"}' | nc logstash-lb.k3s-elk-stack 5044"
```

#### Verify in Kibana

Steps to verify log ingestion

- Open Kibana at http://node-ip:30561
- Go to Management then Stack Management then Index Patterns
- Create index pattern named logs-*
- Go to Discover to view logs
- Search for your test message

#### Verify in Elasticsearch

Check indices directly in Elasticsearch

```bash
kubectl exec -n k3s-elasticsearch k3s-elasticsearch-0 -- curl -XGET http://localhost:9200/_cat/indices?v
```

You should see indices like logs-2024.01.01 or current date

Query for recent logs

```bash
kubectl exec -n k3s-elasticsearch k3s-elasticsearch-0 -- curl -XGET http://localhost:9200/logs-*/_search?pretty
```

## Monitoring

#### Check Logstash Status

View logs from both Logstash pods

```bash
kubectl logs -n k3s-elk-stack logstash-0
kubectl logs -n k3s-elk-stack logstash-1
```

Follow logs in real-time

```bash
kubectl logs -n k3s-elk-stack logstash-0 -f
```

#### Check Kibana Status

View Kibana pod logs

```bash
kubectl logs -n k3s-elk-stack deployment/kibana
```

Check Kibana API health

```bash
kubectl exec -n k3s-elk-stack deployment/kibana -- curl -s http://localhost:5601/api/status
```

#### Check Persistent Storage

Verify PVC binding status

```bash
kubectl get pvc -n k3s-elk-stack
```

Check storage usage

```bash
kubectl exec -n k3s-elk-stack logstash-0 -- df -h /usr/share/logstash/data
kubectl exec -n k3s-elk-stack deployment/kibana -- df -h /usr/share/kibana/data
```

## Troubleshooting

#### Pods Not Starting

Check pod events and logs

```bash
kubectl describe pod pod-name -n k3s-elk-stack
kubectl logs pod-name -n k3s-elk-stack
```

Common issues

- PVC not bound check PV and PVC status
- Image pull errors verify image name and registry access
- Resource constraints check node capacity
- Host path permissions verify /mnt/ssd permissions

#### Cannot Connect to Elasticsearch

Verify k3s-elasticsearch is running

```bash
kubectl get pods -n k3s-elasticsearch
```

Test connectivity from ELK stack namespace

```bash
kubectl run test-es --rm -it --image=curlimages/curl -n k3s-elk-stack -- curl http://k3s-elasticsearch-0.k3s-elasticsearch-headless.k3s-elasticsearch.svc.cluster.local:9200
```

Check Elasticsearch cluster health

```bash
kubectl exec -n k3s-elasticsearch k3s-elasticsearch-0 -- curl -XGET http://localhost:9200/_cluster/health?pretty
```

#### Logs Not Appearing

Check Logstash is receiving and processing logs

```bash
kubectl logs -n k3s-elk-stack logstash-0 --tail=50
kubectl logs -n k3s-elk-stack logstash-1 --tail=50
```

Check Elasticsearch indices

```bash
kubectl exec -n k3s-elasticsearch k3s-elasticsearch-0 -- curl -XGET http://localhost:9200/_cat/indices?v
```

Verify Logstash output configuration

```bash
kubectl get configmap logstash-pipeline -n k3s-elk-stack -o yaml
```

#### StatefulSet Issues

Check StatefulSet status

```bash
kubectl describe statefulset logstash -n k3s-elk-stack
```

Scale down and up to recover

```bash
kubectl scale statefulset logstash --replicas=0 -n k3s-elk-stack
kubectl scale statefulset logstash --replicas=2 -n k3s-elk-stack
```

## Scaling

#### Scale Logstash Replicas

Increase or decrease Logstash replicas based on load

```bash
kubectl scale statefulset logstash --replicas=3 -n k3s-elk-stack
```

Each new pod gets its own persistent volume automatically

Monitor scaling progress

```bash
kubectl get pods -n k3s-elk-stack -w
```

#### Considerations

When scaling Logstash

- Each replica needs 512MB to 1GB memory
- Each replica gets 10Gi persistent storage
- Load balancer distributes traffic automatically
- Scale based on log ingestion rate and processing needs

Do not scale Kibana as it is a stateless UI component and single replica is sufficient

## Cleanup

Remove all ELK stack resources

```bash
kubectl delete namespace k3s-elk-stack
```

Remove persistent volumes if needed

```bash
kubectl delete pv kibana-data-pv
kubectl delete pv logstash-data-pv
```

Remove host directories if needed

```bash
sudo rm -rf /mnt/ssd/kibana-data
```

Note that this does not affect the k3s-elasticsearch cluster or its data

## Related Documentation

- Storage Configuration in docs/STORAGE.md
- Main project README in README.md

## Support

For additional help

- Check Elasticsearch documentation at elastic.co/guide
- Review Logstash documentation at elastic.co/guide/en/logstash
- Review Kibana documentation at elastic.co/guide/en/kibana
