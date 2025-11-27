# documentation

Complete documentation for the ELK stack deployment, configuration, scaling, and usage.

----

## getting started

- [deployment.md](deployment.md) - complete deployment guide with prerequisites and verification steps
- [../readme.md](../readme.md) - project overview and quick start

----

## component documentation

- [elasticsearch.md](elasticsearch.md) - Elasticsearch configuration, operations, and troubleshooting
- Component-specific operations and best practices

----

## operations

- [scaling.md](scaling.md) - scale Elasticsearch and Logstash for high availability and performance
- [production-resources.md](production-resources.md) - resource planning, development vs production configurations
- [storage.md](storage.md) - persistent storage architecture, backup, and restore procedures

----

## usage

- [usage.md](usage.md) - send logs, query data, integrate applications, create visualizations

----

## documentation structure

#### deployment.md

- Prerequisites and requirements
- Step-by-step deployment process
- Post-deployment configuration
- Verification and testing
- Troubleshooting common issues

#### elasticsearch.md

- Component overview and architecture
- Configuration files and settings
- Index management operations
- Health monitoring
- Backup and restore procedures

#### production-resources.md

- Development vs production resource configurations
- Upgrading from development to production
- Resource planning and capacity
- Update strategies and rolling updates
- High availability considerations

#### storage.md

- Storage architecture (host paths, PVs, PVCs)
- Storage component details
- Backup and restore procedures
- Storage expansion and migration
- Troubleshooting storage issues

#### scaling.md

- Elasticsearch multi-node cluster setup
- Logstash replica scaling
- Storage preparation for scaling
- Monitoring scaling operations
- Load distribution verification

#### usage.md

- Elasticsearch API operations (CRUD, search, aggregations)
- Sending logs via Logstash
- Application integration examples (Python, Node.js, Go)
- Kibana usage (index patterns, visualizations, dashboards)
- Log analysis and monitoring

----

## quick reference

#### deployment

```bash
bash setup.sh    # create storage directories
bash deploy.sh   # deploy all components
```

#### access

- Elasticsearch: http://node-ip:30920
- Kibana: http://node-ip:30561
- Logstash: node-ip:30044

#### scaling

```bash
kubectl scale statefulset elk-elasticsearch --replicas=3 -n k3s-elk
kubectl scale statefulset elk-logstash --replicas=2 -n k3s-elk
```

#### updates

```bash
kubectl rollout restart statefulset/elk-elasticsearch -n k3s-elk
kubectl rollout status statefulset/elk-elasticsearch -n k3s-elk
```

----

## additional resources

- Official Elastic documentation: https://www.elastic.co/guide
- Kubernetes StatefulSet documentation
- Kubernetes Persistent Volumes documentation
- k3s documentation: https://docs.k3s.io

----

## contributing to documentation

When adding or updating documentation:

- Use lowercase filenames
- Use `##` for main headings, `####` for subheadings
- Separate sections with `----`
- Include clickable links to related documentation
- Provide code examples where applicable
- Keep technical language clear and professional
