# configmaps

Kubernetes ConfigMap definitions containing configuration files for ELK stack components.

----

## files

- `elasticsearch-config.yaml` - Elasticsearch configuration (elasticsearch.yml)
- `logstash-pipeline.yaml` - Logstash pipeline configuration (logstash.conf)

----

## elasticsearch configuration

#### file: elasticsearch-config.yaml

Contains elasticsearch.yml configuration mounted at `/usr/share/elasticsearch/config/`

#### current settings (development)

- cluster.name: k3s-elasticsearch-cluster
- discovery.type: single-node
- xpack.security.enabled: false
- network.host: 0.0.0.0

#### production settings

For multi-node cluster, update to:

```yaml
discovery.seed_hosts: ["elk-elasticsearch-0.elk-elasticsearch-headless", ...]
cluster.initial_master_nodes: ["elk-elasticsearch-0", ...]
```

See [../docs/scaling.md](../docs/scaling.md) for details.

----

## logstash pipeline

#### file: logstash-pipeline.yaml

Contains logstash.conf pipeline configuration mounted at `/usr/share/logstash/pipeline/`

#### pipeline structure

- Input: TCP port 5044 with json_lines codec
- Filter: JSON parsing for message field
- Output: Elasticsearch with daily index pattern (logs-YYYY.MM.dd)

#### customization

Modify pipeline to add filters, change output index pattern, or add multiple outputs.

----

## updating configuration

#### update configmap

```bash
kubectl edit configmap elk-elasticsearch-config -n k3s-elk
kubectl edit configmap elk-logstash-pipeline -n k3s-elk
```

#### apply changes

Restart pods to load new configuration:

```bash
kubectl rollout restart statefulset/elk-elasticsearch -n k3s-elk
kubectl rollout restart statefulset/elk-logstash -n k3s-elk
```

----

## related documentation

- [../docs/elasticsearch.md](../docs/elasticsearch.md) - elasticsearch configuration details
- [../docs/scaling.md](../docs/scaling.md) - multi-node cluster configuration
- [../docs/usage.md](../docs/usage.md) - logstash pipeline examples
- [../readme.md](../readme.md) - project overview
