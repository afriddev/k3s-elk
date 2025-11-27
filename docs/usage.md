# Usage Guide

## Overview

This guide demonstrates how to use the ELK stack for log collection, indexing, searching, and visualization. Examples cover direct Elasticsearch operations, sending logs through Logstash, and creating visualizations in Kibana.

----

## Elasticsearch Usage

#### Cluster Health Check

Verify Elasticsearch cluster is operational:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_cluster/health?pretty
```

Expected response shows status green with available nodes.

#### Node Information

View detailed node statistics:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_nodes/stats?pretty
```

#### List Indices

View all indices in the cluster:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_cat/indices?v
```

----

## Index Management

#### Create Index

Create a new index with specific settings:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XPUT http://localhost:9200/application-logs -H 'Content-Type: application/json' -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "index.refresh_interval": "5s"
  },
  "mappings": {
    "properties": {
      "timestamp": {"type": "date"},
      "level": {"type": "keyword"},
      "message": {"type": "text"},
      "service": {"type": "keyword"},
      "host": {"type": "keyword"}
    }
  }
}'
```

#### View Index Settings

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_settings?pretty
```

#### View Index Mapping

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_mapping?pretty
```

#### Delete Index

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XDELETE http://localhost:9200/application-logs
```

----

## Document Operations

#### Insert Single Document

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XPOST http://localhost:9200/application-logs/_doc -H 'Content-Type: application/json' -d '{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "INFO",
  "message": "Application started successfully",
  "service": "backend-api",
  "host": "pod-123"
}'
```

#### Insert Document with Specific ID

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XPUT http://localhost:9200/application-logs/_doc/1 -H 'Content-Type: application/json' -d '{
  "timestamp": "2024-01-01T12:01:00Z",
  "level": "WARN",
  "message": "High memory usage detected",
  "service": "backend-api",
  "host": "pod-123"
}'
```

#### Get Document by ID

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_doc/1?pretty
```

#### Update Document

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XPOST http://localhost:9200/application-logs/_update/1 -H 'Content-Type: application/json' -d '{
  "doc": {
    "level": "ERROR"
  }
}'
```

#### Delete Document

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XDELETE http://localhost:9200/application-logs/_doc/1
```

----

## Searching Data

####  Search All Documents

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_search?pretty
```

#### Search with Query

Match specific text:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_search?pretty -H 'Content-Type: application/json' -d '{
  "query": {
    "match": {
      "message": "error"
    }
  }
}'
```

#### Filter by Field Value

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_search?pretty -H 'Content-Type: application/json' -d '{
  "query": {
    "term": {
      "level": "ERROR"
    }
  }
}'
```

#### Range Query

Search by timestamp range:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_search?pretty -H 'Content-Type: application/json' -d '{
  "query": {
    "range": {
      "timestamp": {
        "gte": "2024-01-01T00:00:00Z",
        "lte": "2024-01-01T23:59:59Z"
      }
    }
  }
}'
```

#### Combined Query

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_search?pretty -H 'Content-Type: application/json' -d '{
  "query": {
    "bool": {
      "must": [
        {"match": {"message": "error"}},
        {"term": {"service": "backend-api"}}
      ],
      "filter": [
        {"range": {"timestamp": {"gte": "now-1h"}}}
      ]
    }
  },
  "sort": [{"timestamp": "desc"}],
  "size": 100
}'
```

----

## Logstash Integration

#### Send Logs via TCP

From within cluster using netcat:

```bash
kubectl run test-logger --rm -it --image=busybox -n k3s-elk -- sh -c \
  'echo "{\"message\":\"Test log entry\",\"level\":\"INFO\",\"service\":\"test\"}" | nc logstash.k3s-elk 5044'
```

#### Send Logs from Application Pod

Example deployment that sends logs to Logstash:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: log-producer
  namespace: k3s-elk
spec:
  containers:
  - name: producer
    image: busybox
    command: ["/bin/sh"]
    args:
      - -c
      - |
        while true; do
          echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"level\":\"INFO\",\"message\":\"Sample log message\"}" | nc logstash.k3s-elk 5044
          sleep 5
        done
```

#### Configure Filebeat

Filebeat configuration for sending logs to Logstash:

```yaml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/*.log
    fields:
      service: my-application
      environment: production

output.logstash:
  hosts: ["logstash.k3s-elk.svc.cluster.local:5044"]
  loadbalance: true
```

----

## Application Integration

#### Python Application

Using official Elasticsearch Python client:

```python
from elasticsearch import Elasticsearch
from datetime import datetime

es = Elasticsearch(
    ["http://elasticsearch-0.elasticsearch-headless.k3s-elk.svc.cluster.local:9200"]
)

# Index a document
doc = {
    "timestamp": datetime.utcnow(),
    "level": "INFO",
    "message": "Application event occurred",
    "service": "python-app"
}

result = es.index(index="application-logs", document=doc)
print(f"Document indexed with ID: {result['_id']}")

# Search documents
query = {
    "query": {
        "match": {
            "level": "INFO"
        }
    }
}

results = es.search(index="application-logs", body=query)
for hit in results["hits"]["hits"]:
    print(hit["_source"])
```

#### Node.js Application

Using official Elasticsearch JavaScript client:

```javascript
const { Client } = require('@elastic/elasticsearch');

const client = new Client({
  node: 'http://elasticsearch-0.elasticsearch-headless.k3s-elk.svc.cluster.local:9200'
});

async function indexDocument() {
  const result = await client.index({
    index: 'application-logs',
    document: {
      timestamp: new Date(),
      level: 'INFO',
      message: 'Node.js application event',
      service: 'nodejs-app'
    }
  });
  console.log(`Document indexed: ${result._id}`);
}

async function searchDocuments() {
  const result = await client.search({
    index: 'application-logs',
    query: {
      match: { level: 'INFO' }
    }
  });
  
  result.hits.hits.forEach(hit => {
    console.log(hit._source);
  });
}

indexDocument();
searchDocuments();
```

#### Go Application

Using official Elasticsearch Go client:

```go
package main

import (
    "context"
    "encoding/json"
    "log"
    "strings"
    "time"

    "github.com/elastic/go-elasticsearch/v8"
)

type LogEntry struct {
    Timestamp time.Time `json:"timestamp"`
    Level     string    `json:"level"`
    Message   string    `json:"message"`
    Service   string    `json:"service"`
}

func main() {
    es, _ := elasticsearch.NewClient(elasticsearch.Config{
        Addresses: []string{
            "http://elasticsearch-0.elasticsearch-headless.k3s-elk.svc.cluster.local:9200",
        },
    })

    // Index document
    entry := LogEntry{
        Timestamp: time.Now(),
        Level:     "INFO",
        Message:   "Go application event",
        Service:   "go-app",
    }

    data, _ := json.Marshal(entry)
    res, _ := es.Index(
        "application-logs",
        strings.NewReader(string(data)),
    )
    defer res.Body.Close()

    log.Println(res.String())
}
```

----

## Kibana Usage

#### Access Kibana

Open web browser and navigate to:

```
http://<node-ip>:30561
```

#### Create Index Pattern

- Navigate to Management menu
- Select Stack Management
- Click Index Patterns under Kibana section
- Click Create index pattern button
- Enter index pattern: logs-* or application-logs
- Click Next step
- Select @timestamp or timestamp as Time field
- Click Create index pattern

#### Discover Logs

- Navigate to Discover section from main menu
- Select your index pattern from dropdown
- Use search bar for KQL queries
- Filter by time range using time picker
- Add fields to table view using sidebar

#### KQL Query Examples

Search for specific term:

```
message: "error"
```

Search with field filter:

```
level: "ERROR" AND service: "backend-api"
```

Search with wildcard:

```
message: *timeout*
```

Search with exists:

```
_exists_: error_code
```

#### Create Visualization

- Navigate to Visualize Library
- Click Create visualization button
- Select visualization type (Line, Bar, Pie, etc.)
- Choose your index pattern
- Configure metrics and buckets
- Save visualization with descriptive name

#### Create Dashboard

- Navigate to Dashboard section
- Click Create dashboard button
- Click Add from library to add saved visualizations
- Arrange panels on canvas
- Save dashboard with descriptive name
- Set auto-refresh interval if needed

----

## Log Analysis Examples

#### Count Documents by Log Level

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_search?pretty -H 'Content-Type: application/json' -d '{
  "size": 0,
  "aggs": {
    "levels": {
      "terms": {
        "field": "level"
      }
    }
  }
}'
```

#### Calculate Error Rate

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_search?pretty -H 'Content-Type: application/json' -d '{
  "size": 0,
  "aggs": {
    "error_rate": {
      "filters": {
        "filters": {
          "errors": {"term": {"level": "ERROR"}},
          "total": {"match_all": {}}
        }
      }
    }
  }
}'
```

#### Time-based Histogram

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/application-logs/_search?pretty -H 'Content-Type: application/json' -d '{
  "size": 0,
  "aggs": {
    "logs_over_time": {
      "date_histogram": {
        "field": "timestamp",
        "fixed_interval": "1h"
      }
    }
  }
}'
```

----

## Monitoring and Maintenance

#### Check Index Size

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_cat/indices?v&h=index,store.size,docs.count&s=store.size:desc
```

#### Delete Old Indices

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XDELETE http://localhost:9200/logs-2024.01.*
```

#### Optimize Index

Force merge to reduce segment count:

```bash
kubectl exec -n k3s-elk el asticsearch-0 -- curl -XPOST http://localhost:9200/application-logs/_forcemerge?max_num_segments=1
```

#### Refresh Index

Make recent changes searchable immediately:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XPOST http://localhost:9200/application-logs/_refresh
```

----

## Troubleshooting

#### No Logs Appearing in Kibana

Verify Logstash is receiving logs:

```bash
kubectl logs -n k3s-elk logstash-0 --tail=50
```

Check Elasticsearch indices:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_cat/indices?v
```

Verify index pattern in Kibana matches actual indices.

#### Search Performance Issues

Check cluster health:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_cluster/health?pretty
```

Reduce search result size using size parameter.

Use filters instead of queries when possible for better performance.

Consider adding more Elasticsearch replicas for query load distribution.

#### High Storage Usage

Identify large indices:

```bash
kubectl exec -n k3s-elk elasticsearch-0 -- curl -XGET http://localhost:9200/_cat/indices?v&s=store.size:desc
```

Implement index lifecycle management for automatic deletion.

Reduce retention period for old logs.

----

## Best Practices

- Use structured JSON logging in applications for better searchability
- Include timestamp, level, service, and message fields in all logs
- Use consistent field naming across all services
- Implement log sampling for very high volume applications
- Set appropriate retention policies based on compliance requirements
- Create saved searches for common queries in Kibana
- Build dashboards for key metrics and monitoring
- Use Kibana alerts for critical error conditions
- Monitor Elasticsearch disk usage regularly
- Test index patterns before large-scale log ingestion

----

## Related Documentation

- [deployment.md](deployment.md) - Initial setup procedures
- [elasticsearch.md](elasticsearch.md) - Elasticsearch component details
- [scaling.md](scaling.md) - Scaling for higher load
- [storage.md](storage.md) - Storage configuration
- [readme.md](readme.md) - Project overview
