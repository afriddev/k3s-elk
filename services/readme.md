# services

This directory contains all Kubernetes service definitions for the ELK stack, organized by service type.

----

## directory structure

- `headless/` - ClusterIP None services for StatefulSet pod discovery
- `nodeport/` - NodePort services for external access

----

## headless services

Headless services provide stable network identities for StatefulSet pods and enable direct pod-to-pod communication.

#### files

- `elasticsearch-headless.yaml` - Elasticsearch cluster communication (ports 9200, 9300)
- `logstash-headless.yaml` - Logstash StatefulSet pod discovery (port 5044)

#### usage

Headless services create DNS entries for individual pods:

```
elk-elasticsearch-0.elk-elasticsearch-headless.k3s-elk.svc.cluster.local
elk-elasticsearch-1.elk-elasticsearch-headless.k3s-elk.svc.cluster.local
elk-logstash-0.elk-logstash-headless.k3s-elk.svc.cluster.local
```

----

## nodeport services

NodePort services expose components externally on specific node ports for access from outside the cluster.

#### files

- `elasticsearch-nodeport.yaml` - External Elasticsearch API access (NodePort 30920)
- `logstash-nodeport.yaml` - External log ingestion (NodePort 30044)
- `kibana-nodeport.yaml` - Kibana web interface (NodePort 30561)

#### access points

- Elasticsearch: http://node-ip:30920
- Kibana: http://node-ip:30561
- Logstash: node-ip:30044

----

## related documentation

- [../docs/deployment.md](../docs/deployment.md) - deployment procedures
- [../docs/scaling.md](../docs/scaling.md) - scaling and HA configuration
- [../readme.md](../readme.md) - project overview
