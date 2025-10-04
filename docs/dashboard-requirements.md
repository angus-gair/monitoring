# Dashboard Requirements Specification

## Overview

Detailed specifications for all Grafana dashboards in the monitoring system.

---

## Dashboard Standards

### Global Standards
- **Theme**: Dark theme (default)
- **Time Range**: Last 6 hours (default)
- **Refresh Interval**: 30 seconds (configurable)
- **Timezone**: Browser local time
- **Variables**: Consistent naming (`$instance`, `$job`, `$container`)

### Panel Standards
- **Title Format**: Clear, descriptive titles
- **Descriptions**: Hover tooltips with metric explanations
- **Colors**: Consistent palette across dashboards
- **Thresholds**: Red (critical), Orange (warning), Green (ok)
- **Units**: Auto-detect or manually set (bytes, percent, seconds)

### Layout Standards
- **Grid**: 24-column grid system
- **Row Height**: 8-10 units standard
- **Grouping**: Related panels in rows
- **Spacing**: Consistent padding

---

## Dashboard 1: System Overview

### Purpose
High-level view of host machine health and performance.

### Target Audience
System administrators, DevOps engineers

### Refresh Interval
30 seconds (auto-refresh)

### Variables
```yaml
- name: instance
  type: query
  query: label_values(node_uname_info, instance)
  default: All
  multi: false
```

### Rows & Panels

#### Row 1: System Health Summary
**Height**: 6 units

1. **Health Score Gauge** (6x6)
   - **Type**: Gauge
   - **Metric**: Composite score (CPU + Memory + Disk)
   - **Query**:
     ```promql
     (
       (100 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) * 0.3 +
       (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100) * 0.3 +
       (avg(node_filesystem_avail_bytes / node_filesystem_size_bytes * 100)) * 0.4
     )
     ```
   - **Thresholds**: 0-60 (red), 60-80 (orange), 80-100 (green)

2. **System Uptime** (6x6)
   - **Type**: Stat
   - **Metric**: `node_time_seconds - node_boot_time_seconds`
   - **Format**: Duration (days, hours, minutes)
   - **Color**: Static (green)

3. **CPU Cores** (6x6)
   - **Type**: Stat
   - **Metric**: `count(node_cpu_seconds_total{mode="idle"})`
   - **Label**: "Available Cores"
   - **Color**: Static (blue)

4. **Total Memory** (6x6)
   - **Type**: Stat
   - **Metric**: `node_memory_MemTotal_bytes`
   - **Format**: Bytes (IEC)
   - **Color**: Static (blue)

#### Row 2: CPU Metrics
**Height**: 10 units

5. **CPU Usage by Mode** (12x10)
   - **Type**: Time series (stacked area)
   - **Metrics**:
     ```promql
     sum by (mode) (rate(node_cpu_seconds_total[5m])) * 100
     ```
   - **Legend**: Bottom, show values
   - **Colors**:
     - idle: green
     - system: red
     - user: blue
     - iowait: orange
   - **Y-axis**: 0-100%, fixed

6. **CPU Load Average** (12x10)
   - **Type**: Time series (line)
   - **Metrics**:
     ```promql
     node_load1
     node_load5
     node_load15
     ```
   - **Thresholds**: >6 (number of cores)
   - **Y-axis**: Auto

#### Row 3: Memory Metrics
**Height**: 10 units

7. **Memory Usage** (12x10)
   - **Type**: Time series (stacked area)
   - **Metrics**:
     ```promql
     node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes  # Used
     node_memory_Cached_bytes  # Cached
     node_memory_Buffers_bytes  # Buffers
     node_memory_MemAvailable_bytes  # Available
     ```
   - **Format**: Bytes (IEC)
   - **Legend**: Right side, as table

8. **Memory Utilization %** (12x10)
   - **Type**: Gauge
   - **Metric**:
     ```promql
     (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
     ```
   - **Thresholds**: 0-70 (green), 70-85 (orange), 85-100 (red)
   - **Format**: Percent (0-100)

#### Row 4: Disk Metrics
**Height**: 10 units

9. **Disk Space Usage** (12x10)
   - **Type**: Bar gauge (horizontal)
   - **Metric**:
     ```promql
     (node_filesystem_size_bytes{fstype!~"tmpfs|fuse.*"} -
      node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.*"}) /
      node_filesystem_size_bytes{fstype!~"tmpfs|fuse.*"} * 100
     ```
   - **Group By**: mountpoint
   - **Thresholds**: 0-70 (green), 70-85 (orange), 85-100 (red)
   - **Format**: Percent (0-100)

10. **Disk I/O** (12x10)
    - **Type**: Time series (line)
    - **Metrics**:
      ```promql
      rate(node_disk_read_bytes_total[5m])  # Read
      rate(node_disk_written_bytes_total[5m])  # Write
      ```
    - **Format**: Bytes/sec
    - **Legend**: Bottom

#### Row 5: Network Metrics
**Height**: 10 units

11. **Network Traffic** (12x10)
    - **Type**: Time series (area)
    - **Metrics**:
      ```promql
      rate(node_network_receive_bytes_total{device!~"lo|veth.*|docker.*|br-.*"}[5m])
      rate(node_network_transmit_bytes_total{device!~"lo|veth.*|docker.*|br-.*"}[5m])
      ```
    - **Format**: Bytes/sec
    - **Transform**: Receive as negative values (mirror chart)

12. **Network Errors** (12x10)
    - **Type**: Time series (line)
    - **Metrics**:
      ```promql
      rate(node_network_receive_errs_total[5m])
      rate(node_network_transmit_errs_total[5m])
      ```
    - **Color**: Red/orange
    - **Alert**: > 0

#### Row 6: System Details
**Height**: 12 units

13. **Top Processes by CPU** (12x12)
    - **Type**: Table
    - **Metric**:
      ```promql
      topk(10, rate(node_processes_cpu_time_seconds_total[5m]))
      ```
    - **Columns**: Process name, CPU %, Memory %
    - **Sort**: CPU % descending

14. **Open File Descriptors** (12x12)
    - **Type**: Time series (line)
    - **Metric**:
      ```promql
      node_filefd_allocated
      node_filefd_maximum
      ```
    - **Thresholds**: Warn at 80% of max

### Annotations
- System reboots (node_boot_time_seconds changes)
- Alert firing events

### Links
- Link to Prometheus targets page
- Link to Node Exporter metrics endpoint
- Link to detailed system logs

---

## Dashboard 2: Docker Containers

### Purpose
Monitor all Docker containers and their resource usage.

### Target Audience
DevOps engineers, container administrators

### Refresh Interval
15 seconds (auto-refresh)

### Variables
```yaml
- name: container
  type: query
  query: label_values(container_last_seen, name)
  default: All
  multi: true
  include_all: true

- name: image
  type: query
  query: label_values(container_last_seen, image)
  default: All
  multi: true
  include_all: true
```

### Rows & Panels

#### Row 1: Container Overview
**Height**: 6 units

1. **Total Containers** (6x6)
   - **Type**: Stat
   - **Metric**: `count(container_last_seen{name!=""})`
   - **Color**: Blue

2. **Running Containers** (6x6)
   - **Type**: Stat
   - **Metric**: `count(container_last_seen{name!=""} > 0)`
   - **Color**: Green

3. **CPU Usage (All)** (6x6)
   - **Type**: Gauge
   - **Metric**:
     ```promql
     sum(rate(container_cpu_usage_seconds_total{name!=""}[5m])) * 100
     ```
   - **Thresholds**: 0-70 (green), 70-90 (orange), 90-100 (red)

4. **Memory Usage (All)** (6x6)
   - **Type**: Gauge
   - **Metric**:
     ```promql
     sum(container_memory_usage_bytes{name!=""}) / 1024^3
     ```
   - **Format**: Gigabytes
   - **Thresholds**: Based on available RAM

#### Row 2: Container Resource Usage
**Height**: 10 units

5. **CPU Usage per Container** (12x10)
   - **Type**: Time series (line)
   - **Metric**:
     ```promql
     rate(container_cpu_usage_seconds_total{name=~"$container"}[5m]) * 100
     ```
   - **Legend**: Show container name
   - **Format**: Percent

6. **Memory Usage per Container** (12x10)
   - **Type**: Time series (line)
   - **Metric**:
     ```promql
     container_memory_usage_bytes{name=~"$container"}
     ```
   - **Format**: Bytes (IEC)
   - **Legend**: Show container name

#### Row 3: Container Network
**Height**: 10 units

7. **Network I/O per Container** (24x10)
   - **Type**: Time series (area)
   - **Metrics**:
     ```promql
     rate(container_network_receive_bytes_total{name=~"$container"}[5m])
     rate(container_network_transmit_bytes_total{name=~"$container"}[5m])
     ```
   - **Format**: Bytes/sec
   - **Legend**: Container + direction

#### Row 4: Container Filesystem
**Height**: 10 units

8. **Disk Usage per Container** (12x10)
   - **Type**: Bar gauge
   - **Metric**:
     ```promql
     container_fs_usage_bytes{name=~"$container"}
     ```
   - **Format**: Bytes (IEC)

9. **Disk I/O per Container** (12x10)
   - **Type**: Time series (line)
   - **Metrics**:
     ```promql
     rate(container_fs_reads_bytes_total{name=~"$container"}[5m])
     rate(container_fs_writes_bytes_total{name=~"$container"}[5m])
     ```
   - **Format**: Bytes/sec

#### Row 5: Container Details
**Height**: 12 units

10. **Container Status Table** (24x12)
    - **Type**: Table
    - **Metrics**:
      - Container name
      - Image
      - State (running/stopped)
      - Uptime
      - CPU %
      - Memory usage
      - Network I/O
    - **Sort**: Name (ascending)
    - **Links**: Click to filter dashboard

### Alerts
- Container down (expected to be running)
- High CPU usage (> 80% for 5 minutes)
- High memory usage (> 90%)
- Container restarts (> 3 in 10 minutes)

---

## Dashboard 3: Node.js / NPM Monitoring

### Purpose
Monitor Node.js applications and npm processes.

### Target Audience
Application developers, DevOps engineers

### Refresh Interval
30 seconds

### Variables
```yaml
- name: process
  type: query
  query: label_values(npm_process_cpu_seconds_total, process)
  default: All
  multi: true
  include_all: true
```

### Rows & Panels

#### Row 1: Process Overview
**Height**: 6 units

1. **Active NPM Processes** (8x6)
   - **Type**: Stat
   - **Metric**: `count(npm_processes_total)`
   - **Color**: Green if > 0

2. **Total CPU Usage** (8x6)
   - **Type**: Gauge
   - **Metric**: `sum(rate(npm_process_cpu_seconds[5m])) * 100`
   - **Format**: Percent

3. **Total Memory** (8x6)
   - **Type**: Stat
   - **Metric**: `sum(npm_process_memory_bytes) / 1024^2`
   - **Format**: Megabytes

#### Row 2: Node.js Runtime Metrics
**Height**: 10 units

4. **Event Loop Lag** (12x10)
   - **Type**: Time series (line)
   - **Metric**: `nodejs_eventloop_lag_seconds`
   - **Threshold**: > 0.1s (warning), > 0.5s (critical)
   - **Format**: Seconds

5. **Heap Memory** (12x10)
   - **Type**: Time series (area)
   - **Metrics**:
     ```promql
     nodejs_heap_size_total_bytes
     nodejs_heap_size_used_bytes
     ```
   - **Format**: Bytes (IEC)

#### Row 3: Process Details
**Height**: 10 units

6. **CPU per Process** (12x10)
   - **Type**: Time series (line)
   - **Metric**:
     ```promql
     rate(npm_process_cpu_seconds{process=~"$process"}[5m]) * 100
     ```

7. **Memory per Process** (12x10)
   - **Type**: Time series (line)
   - **Metric**: `npm_process_memory_bytes{process=~"$process"}`

#### Row 4: Garbage Collection
**Height**: 10 units

8. **GC Duration** (12x10)
   - **Type**: Histogram
   - **Metric**: `nodejs_gc_duration_seconds`
   - **Format**: Milliseconds

9. **Active Handles/Requests** (12x10)
   - **Type**: Time series (line)
   - **Metrics**:
     ```promql
     nodejs_active_handles_total
     nodejs_active_requests_total
     ```

#### Row 5: Process Table
**Height**: 12 units

10. **Process Details** (24x12)
    - **Type**: Table
    - **Columns**:
      - Process name
      - PID
      - Uptime
      - CPU %
      - Memory MB
      - Event loop lag
      - Heap used %
    - **Sort**: CPU % descending

---

## Dashboard 4: Prometheus Self-Monitoring

### Purpose
Monitor Prometheus server health and performance.

### Rows & Panels

#### Row 1: Storage
1. **TSDB Size** - Disk usage
2. **Sample Ingestion Rate** - Samples/sec
3. **Active Time Series** - Cardinality

#### Row 2: Scraping
4. **Scrape Duration** - P95/P99
5. **Failed Scrapes** - Error rate
6. **Target Status** - Up/down

#### Row 3: Query Performance
7. **Query Duration** - P95/P99
8. **Active Queries** - Concurrent queries
9. **Query Rate** - Queries/sec

---

## Dashboard 5: Alerts Overview

### Purpose
Centralized view of all active and recent alerts.

### Rows & Panels

#### Row 1: Current Status
1. **Active Alerts** - Count by severity
2. **Firing Rate** - Alerts/hour
3. **Alert States** - Pie chart

#### Row 2: Alert Timeline
4. **Recent Alerts** - Timeline visualization
5. **Alert History** - Table with details

#### Row 3: Alert Details
6. **Alerts by Label** - Group by job, instance
7. **Top Firing Alerts** - Most frequent

---

## Dashboard Provisioning

### Auto-import Configuration
```yaml
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/dashboards
```

### Dashboard Files
- `system-overview.json`
- `docker-containers.json`
- `nodejs-npm.json`
- `prometheus-stats.json`
- `alerts-overview.json`

---

## Export & Version Control

### Process
1. Design dashboards in Grafana UI
2. Export as JSON via API or UI
3. Commit to Git repository
4. Auto-provision on deployment

### API Export Command
```bash
curl -H "Authorization: Bearer $API_KEY" \
  http://localhost:3000/api/dashboards/uid/$DASHBOARD_UID \
  | jq '.dashboard' > dashboard.json
```

---

## Testing Requirements

### Functional Tests
- All panels render without errors
- Variables populate correctly
- Links navigate properly
- Queries return data

### Performance Tests
- Dashboard load time < 3 seconds
- Query response time < 1 second
- Auto-refresh doesn't cause browser lag

### Visual Tests
- Consistent color scheme
- Readable text sizes
- Proper alignment
- Responsive layout

---

## Maintenance

### Update Schedule
- Review quarterly
- Update based on new metrics
- Incorporate user feedback

### Ownership
- DevOps team maintains infrastructure dashboards
- Development team maintains application dashboards
