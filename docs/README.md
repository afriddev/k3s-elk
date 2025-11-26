# ELK Stack with Grafana on Kubernetes

## Overview

This project provides a production-ready ELK (Elasticsearch, Logstash, Kibana) Stack with Grafana for centralized logging and visualization on Kubernetes (K3s). It connects to the separately deployed k3s-elasticsearch cluster for data persistence.

## Components

- Logstash 8.10.2 for log ingestion and processing
- Kibana 8.10.2 for log exploration and visualization
- Grafana 10.4.2 for advanced dashboards and alerting
- Integration with k3s-elasticsearch for data storage

## Prerequisites

#### k3s-elasticsearch Cluster
The k3s-elasticsearch cluster must be deployed and running before deploying this stack.

Verify it is running:
```bash
kubectl get pods -n k3s-elasticsearch
kubectl exec -n k3s-elasticsearch k3s-elasticsearch-0 -- curl -XGET http://localhost:9200/_cluster/health
```

#### Kubernetes Cluster
- K3s or any Kubernetes cluster (v1.24+)
- kubectl configured with cluster access
- Node with at least 4GB RAM, 2 vCPUs

#### Software Requirements
- kubectl CLI tool

## Architecture

#### Namespace
All components deploy to the k3s-elk-stack namespace.

#### Data Flow
1. Applications send JSON logs to Logstash on port 5044
2. Logstash processes and forwards logs to k3s-elasticsearch
3. Kibana and Grafana query k3s-elasticsearch for visualization

#### Services
- Logstash: Internal ClusterIP on port 5044
- Kibana: NodePort on port 30561
- Grafana: NodePort on port 30300

## Directory Structure

```
k3s-elk-stack/
├── namespace/
│   └── namespace.yaml
├── logstash/
│   ├── logstash-config.yaml
│   └── logstash-deployment.yaml
├── kibana/
│   └── kibana-deployment.yaml
├── grafana/
│   └── grafana-deployment.yaml
├── deploy.sh
└── docs/
    ├── README.md
    └── GRAFANA.md
```

## Installation

#### Deploy ELK Stack

Run the automated deployment script:

```bash
bash deploy.sh
```

#### Verify Deployment

```bash
kubectl get pods -n k3s-elk-stack
kubectl get svc -n k3s-elk-stack
```

## Configuration

#### Logstash

Logstash is configured to:
- Accept JSON logs on TCP port 5044
- Parse JSON messages
- Forward to k3s-elasticsearch with daily indices (logs-YYYY.MM.dd)

#### Kibana

Kibana is pre-configured to connect to k3s-elasticsearch. Access it at:
```
http://<node-ip>:30561
```

#### Grafana

Grafana runs with default credentials. Access it at:
```
http://<node-ip>:30300
Username: admin
Password: admin
```

See GRAFANA.md for data source configuration.

## Accessing Services

#### Kibana

External access via NodePort:
```
http://<node-ip>:30561
```

#### Grafana

External access via NodePort:
```
http://<node-ip>:30300
```

#### Logstash (from applications)

Internal access from within the cluster:
```
logstash.k3s-elk-stack.svc.cluster.local:5044
```

## Testing

#### Send Test Log

From within the cluster:

```bash
kubectl run test-logger --rm -it --image=busybox -- sh -c "echo '{\"message\":\"Test log entry\",\"level\":\"info\",\"timestamp\":\"2024-01-01T00:00:00Z\"}' | nc logstash.k3s-elk-stack 5044"
```

#### Verify in Kibana

1. Open Kibana at `http://<node-ip>:30561`
2. Go to Management → Index Patterns
3. Create index pattern: `logs-*`
4. Go to Discover to view logs

#### Verify in Elasticsearch

```bash
kubectl exec -n k3s-elasticsearch k3s-elasticsearch-0 -- curl -XGET http://localhost:9200/_cat/indices?v
```

You should see indices like `logs-2024.01.01`.

## Monitoring

#### Check Logstash Status

```bash
kubectl logs -n k3s-elk-stack deployment/logstash
```

#### Check Kibana Status

```bash
kubectl logs -n k3s-elk-stack deployment/kibana
```

#### Check Grafana Status

```bash
kubectl logs -n k3s-elk-stack deployment/grafana
```

## Troubleshooting

#### Pods Not Starting

Check events and logs:
```bash
kubectl describe pod <pod-name> -n k3s-elk-stack
kubectl logs <pod-name> -n k3s-elk-stack
```

#### Cannot Connect to Elasticsearch

Verify k3s-elasticsearch is running:
```bash
kubectl get pods -n k3s-elasticsearch
```

Test connectivity from ELK stack namespace:
```bash
kubectl run test-es --rm -it --image=curlimages/curl -n k3s-elk-stack -- curl http://k3s-elasticsearch-0.k3s-elasticsearch-headless.k3s-elasticsearch.svc.cluster.local:9200
```

#### Logs Not Appearing

Check Logstash is receiving logs:
```bash
kubectl logs -n k3s-elk-stack deployment/logstash --tail=50
```

Check Elasticsearch indices:
```bash
kubectl exec -n k3s-elasticsearch k3s-elasticsearch-0 -- curl -XGET http://localhost:9200/_cat/indices?v
```

## Cleanup

Remove all ELK stack resources:

```bash
kubectl delete namespace k3s-elk-stack
```

Note: This does not affect the k3s-elasticsearch cluster or its data.

## License

This project is part of the Hospital Information System deployment.
