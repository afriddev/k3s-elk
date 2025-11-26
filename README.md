# ELK Stack with Grafana for K3s

## Overview

This repository contains a production-ready ELK (Elasticsearch, Logstash, Kibana) Stack with Grafana for centralized logging and visualization on Kubernetes (K3s). It connects to the k3s-elasticsearch cluster for data storage.

## Documentation

Detailed documentation is available in the `docs/` folder:

*   **[Deployment Guide](docs/README.md)**: Complete installation and configuration instructions.
*   **[Grafana Setup](docs/GRAFANA.md)**: How to configure Grafana dashboards and data sources.

## Quick Start

### 1. Prerequisites

**Ensure k3s-elasticsearch is deployed and running:**
```bash
kubectl get pods -n k3s-elasticsearch
```

**Check K3s Status:**
```bash
systemctl status k3s
```

### 2. Deploy ELK Stack

Run the automated deployment script:

```bash
bash deploy.sh
```

### 3. Verification

Check the health of your stack:

**Check Pods:**
```bash
kubectl get pods -n k3s-elk-stack
```

**Check Services:**
```bash
kubectl get svc -n k3s-elk-stack
```

## Project Structure

*   `logstash/`: Logstash configuration and deployment.
*   `kibana/`: Kibana configuration and deployment.
*   `grafana/`: Grafana configuration and deployment.
*   `namespace/`: Namespace definition.
*   `docs/`: Detailed documentation.
*   `deploy.sh`: Script to apply Kubernetes manifests.

## Access Points

*   **Kibana**: `http://<node-ip>:30561`
*   **Grafana**: `http://<node-ip>:30300` (admin/admin)
*   **Logstash**: Internal - `logstash:5044`
*   **Elasticsearch**: `http://k3s-elasticsearch-0.k3s-elasticsearch-headless.k3s-elasticsearch.svc.cluster.local:9200`

## Usage

Send logs to Logstash on port 5044 and they will be stored in Elasticsearch and visualized in Kibana and Grafana.

## Support

For detailed configuration and troubleshooting, refer to the documentation in the `docs/` directory.
