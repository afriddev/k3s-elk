# ELK Stack for Kubernetes

A production-ready, highly available ELK stack (Elasticsearch, Logstash, Kibana) deployment for Kubernetes (K3s). This project features a modular architecture, zero-downtime rolling updates, and comprehensive resource management suitable for both development and production environments.

----

## 🚀 Quick Start

### 1. Setup Storage
Initialize the required host directories for persistent storage.
```bash
bash setup.sh
```

### 2. Deploy Stack
Deploy all components (Namespace, ConfigMaps, Storage, Services, StatefulSets, Deployments).
```bash
bash deploy.sh
```

### 3. Verify Deployment
Check the status of pods and services.
```bash
kubectl get pods -n k3s-elk
```

----

## 📚 Documentation

Detailed documentation is available in the `docs/` directory.

- **[Deployment Guide](docs/deployment.md)** - Step-by-step installation, prerequisites, and verification.
- **[Elasticsearch Configuration](docs/elasticsearch.md)** - Deep dive into Elasticsearch settings, clustering, and maintenance.
- **[Production Resources](docs/production-resources.md)** - Resource planning, capacity sizing, and production tuning.
- **[Storage Architecture](docs/storage.md)** - Persistent storage details, backup/restore procedures.
- **[Scaling Guide](docs/scaling.md)** - Instructions for scaling Elasticsearch and Logstash replicas.
- **[Usage Guide](docs/usage.md)** - Examples for sending logs, querying data, and using Kibana.

----

## 📂 Project Structure

This project is organized into logical components, each with its own documentation.

- **[configmaps/](configmaps/readme.md)** - Configuration files for Elasticsearch and Logstash pipelines.
- **[deployments/](deployments/readme.md)** - Stateless application deployments (Kibana).
- **[services/](services/readme.md)** - Network services organized by type (Headless & NodePort).
- **[statefulsets/](statefulsets/readme.md)** - Stateful applications (Elasticsearch & Logstash).
- **[storage/](storage/readme.md)** - Persistent Volume definitions and Storage Classes.

----

## 🔌 Access Points

| Component | External Access (NodePort) | Internal Cluster DNS |
|-----------|----------------------------|----------------------|
| **Elasticsearch** | `http://<node-ip>:30920` | `elk-elasticsearch-headless.k3s-elk` |
| **Kibana** | `http://<node-ip>:30561` | `elk-kibana-nodeport.k3s-elk` |
| **Logstash** | `<node-ip>:30044` | `elk-logstash-headless.k3s-elk` |

----

## ⚙️ Configuration & Resources

### Development (Default)
Optimized for low-resource environments (e.g., local testing).
- **Elasticsearch**: 1 Replica, 1Gi RAM, 20Gi Storage
- **Logstash**: 1 Replica, 512Mi RAM, 10Gi Storage
- **Kibana**: 1 Replica, 512Mi RAM, 5Gi Storage

### Production
Ready for high availability and volume.
- **Elasticsearch**: 3+ Replicas, 4Gi+ RAM, 100Gi+ Storage
- **Logstash**: 2+ Replicas, 2Gi+ RAM
- **Update Strategy**: Rolling Updates with Zero Downtime

See **[Production Resources](docs/production-resources.md)** for upgrade instructions.

----

## 🛠️ Operations

### Scaling
Scale components easily using kubectl.
```bash
# Scale Elasticsearch to 3 nodes
kubectl scale statefulset elk-elasticsearch --replicas=3 -n k3s-elk
```

### Updates
Perform zero-downtime updates.
```bash
# Update Image
kubectl set image statefulset/elk-elasticsearch elasticsearch=docker.elastic.co/elasticsearch/elasticsearch:8.11.0 -n k3s-elk
```

----

## 🧹 Cleanup

To remove the entire stack and data:
```bash
kubectl delete namespace k3s-elk
# Warning: This deletes persistent data
sudo rm -rf /mnt/ssd/elasticsearch /mnt/ssd/kibana-data
```

----

## 🆘 Support

For additional help, refer to the [docs/](docs/readme.md) directory or the official [Elastic Stack Documentation](https://www.elastic.co/guide/index.html).
