## ELK Stack for K3s

## Overview

This repository contains a production-ready ELK stack for centralized logging on Kubernetes. The stack includes Elasticsearch for data storage, Logstash for log processing with high availability, and Kibana for visualization.

For metrics monitoring with Grafana and Prometheus, see the separate k3s-monitoring project.

## Documentation

Detailed documentation is available in the docs folder

- Deployment Guide in docs/README.md
- Storage Configuration in docs/STORAGE.md

## Quick Start

#### Prerequisites

Ensure k3s-elasticsearch is deployed and running

```bash
kubectl get pods -n k3s-elasticsearch
```

Check K3s status

```bash
systemctl status k3s
```

#### Setup Storage Directories

Create the required storage directories on the host

```bash
bash setup.sh
```

This creates the following directories
- /mnt/ssd/kibana-data for Kibana saved objects and dashboards

Note that Logstash uses dynamic persistent volume provisioning via StatefulSet

#### Deploy ELK Stack

Run the automated deployment script

```bash
bash deploy.sh
```

#### Verification

Check the health of your stack

Check pods

```bash
kubectl get pods -n k3s-elk-stack
```

Check services

```bash
kubectl get svc -n k3s-elk-stack
```

Check StatefulSet status

```bash
kubectl get statefulset -n k3s-elk-stack
```

## Project Structure

- storage for persistent volume and claim definitions
- logstash for Logstash configuration StatefulSet and services
  - logstash-config.yaml for pipeline configuration
  - logstash-statefulset.yaml for StatefulSet definition
  - logstash-service-headless.yaml for headless service
  - logstash-service.yaml for NodePort service
- kibana for Kibana deployment and service
  - kibana-deployment.yaml for Deployment definition
  - kibana-service.yaml for NodePort service
- namespace for namespace definition
- docs for detailed documentation
- setup.sh script to create host storage directories
- deploy.sh script to apply Kubernetes manifests

## Access Points

- Kibana at http://node-ip:30561
- Logstash external at http://node-ip:30044 for log ingestion from outside cluster
- Logstash internal at logstash.k3s-elk-stack:5044 for in-cluster applications
- Elasticsearch at http://k3s-elasticsearch-0.k3s-elasticsearch-headless.k3s-elasticsearch.svc.cluster.local:9200

## Architecture

#### Logstash High Availability

Logstash runs as a StatefulSet with 2 replicas for high availability

- Each pod has its own persistent storage via volumeClaimTemplates
- Headless service enables direct pod access
- Load balancer service distributes traffic across replicas
- Ensures continuous log collection even during pod failures

#### Kibana

Kibana runs as a single Deployment

- Uses persistent storage for saved objects and dashboards
- No HA needed as it is stateless UI layer

## Usage

Send logs to Logstash on port 5044 and they will be stored in Elasticsearch and visualized in Kibana

Example using Filebeat

```bash
output.logstash:
  hosts: ["logstash-lb.k3s-elk-stack:5044"]
  loadbalance: true
```

## Support

For detailed configuration and troubleshooting, refer to the documentation in the docs directory
