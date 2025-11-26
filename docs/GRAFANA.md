## Grafana Configuration Guide

This guide explains how to configure Grafana to connect to Elasticsearch and create dashboards for log visualization.

#### 1. Access Grafana

Open Grafana in your browser:
```
http://<node-ip>:30300
```

Login with default credentials:
- Username: admin
- Password: admin

You will be prompted to change the password on first login.

#### 2. Add Elasticsearch Data Source

Navigate to: Configuration (gear icon) → Data Sources → Add data source

Select Elasticsearch and configure:

**Settings:**
- Name: Elasticsearch
- URL: `http://k3s-elasticsearch-0.k3s-elasticsearch-headless.k3s-elasticsearch.svc.cluster.local:9200`
- Access: Server (default)

**Elasticsearch details:**
- Index name: `logs-*`
- Pattern: Daily
- Time field name: `@timestamp`
- Version: 8.0+

Click Save and Test. You should see a green success message.

#### 3. Create Your First Dashboard

Navigate to: Create (plus icon) → Dashboard → Add new panel

**Query Configuration:**
1. Select Elasticsearch as the data source
2. In the query editor, use:
   - Index: `logs-*`
   - Metrics: Count
   - Group by: Date Histogram on @timestamp

**Visualization:**
- Choose visualization type (e.g., Time series, Bar chart, Table)
- Configure display options as needed

Click Apply to add the panel to your dashboard.

#### 4. Common Dashboard Panels

**Log Volume Over Time:**
```
Query:
- Metric: Count
- Group by: Date Histogram (@timestamp, Auto interval)
Visualization: Time series
```

**Logs by Level:**
```
Query:
- Metric: Count
- Group by: Terms (field: level.keyword, Top 10)
Visualization: Pie chart or Bar chart
```

**Recent Logs Table:**
```
Query:
- Metric: Logs
- Size: 100
- Sort: @timestamp desc
Visualization: Table
Columns: @timestamp, level, message
```

**Error Rate:**
```
Query:
- Metric: Count
- Filter: level:"ERROR"
- Group by: Date Histogram (@timestamp, 1h)
Visualization: Time series with threshold
```

#### 5. Example: Application Logs Dashboard

Create a dashboard with these panels:

1. Total Logs (Stat panel)
   - Metric: Count
   - Time range: Last 24h

2. Log Volume (Time series)
   - Metric: Count
   - Group by: Date Histogram (@timestamp, 5m)

3. Logs by Severity (Pie chart)
   - Metric: Count
   - Group by: Terms (level.keyword)

4. Error Logs Table
   - Filter: level:"ERROR"
   - Show: @timestamp, message, source

5. Top Error Messages (Bar chart)
   - Filter: level:"ERROR"
   - Group by: Terms (message.keyword, Top 10)

#### 6. Setting Up Alerts

Navigate to: Alerting → Alert rules → New alert rule

**Example: High Error Rate Alert**

1. Query:
   - Data source: Elasticsearch
   - Query: Count where level="ERROR"
   - Time range: Last 5 minutes

2. Condition:
   - When: Last value
   - Is above: 10

3. Alert details:
   - Name: High Error Rate
   - Folder: General alerting
   - Evaluation: Every 1m for 5m

4. Notifications:
   - Configure contact points (email, Slack, etc.)

#### 7. Import Pre-built Dashboards

You can import community dashboards:

1. Go to: Create (plus icon) → Import
2. Enter dashboard ID or upload JSON
3. Select Elasticsearch as data source

**Recommended Dashboard IDs:**
- Elasticsearch Logs: 13407
- Log Analysis: 12019

#### 8. Variables for Dynamic Dashboards

Create variables to make dashboards interactive:

Navigate to: Dashboard settings (gear icon) → Variables → Add variable

**Example: Application Filter**
- Name: application
- Type: Query
- Data source: Elasticsearch
- Query: `{"find": "terms", "field": "application.keyword"}`

Use in panels with: `application:$application`

#### 9. Best Practices

**Performance:**
- Use time range filters to limit data
- Index patterns should match only needed indices
- Use aggregations instead of fetching all documents

**Visualization:**
- Use consistent time ranges across panels
- Add descriptions to panels
- Group related panels together

**Maintenance:**
- Regularly review and update dashboards
- Remove unused panels and dashboards
- Set appropriate refresh intervals

#### 10. Troubleshooting

**Cannot connect to Elasticsearch:**
- Verify k3s-elasticsearch pods are running
- Check Elasticsearch URL is correct
- Test connectivity from Grafana pod

**No data in dashboards:**
- Verify index pattern matches actual indices
- Check time range includes data
- Ensure @timestamp field exists

**Slow queries:**
- Reduce time range
- Use more specific filters
- Add index pattern with date format

## Additional Resources

For advanced Grafana features, refer to:
- Grafana official documentation
- Elasticsearch query DSL guide
- Grafana community dashboards
