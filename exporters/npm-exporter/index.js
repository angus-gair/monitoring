const express = require('express');
const client = require('prom-client');
const { execSync } = require('child_process');
const fs = require('fs');

const app = express();
const PORT = process.env.METRICS_PORT || 9101;

// Create a Registry to register metrics
const register = new client.Registry();

// Add default metrics (memory, CPU, etc.)
client.collectDefaultMetrics({ register });

// Custom metrics for NPM processes
const npmProcessCount = new client.Gauge({
  name: 'npm_process_count',
  help: 'Number of running NPM processes',
  registers: [register]
});

const nodeProcessCount = new client.Gauge({
  name: 'node_process_count',
  help: 'Number of running Node.js processes',
  registers: [register]
});

const npmProcessMemory = new client.Gauge({
  name: 'npm_process_memory_bytes',
  help: 'Memory usage of NPM processes in bytes',
  labelNames: ['pid', 'command'],
  registers: [register]
});

const nodeProcessMemory = new client.Gauge({
  name: 'node_process_memory_bytes',
  help: 'Memory usage of Node.js processes in bytes',
  labelNames: ['pid', 'command'],
  registers: [register]
});

const npmProcessCpu = new client.Gauge({
  name: 'npm_process_cpu_percent',
  help: 'CPU usage percentage of NPM processes',
  labelNames: ['pid', 'command'],
  registers: [register]
});

const nodeProcessCpu = new client.Gauge({
  name: 'node_process_cpu_percent',
  help: 'CPU usage percentage of Node.js processes',
  labelNames: ['pid', 'command'],
  registers: [register]
});

// Docker container metrics
const dockerContainerCount = new client.Gauge({
  name: 'docker_container_count',
  help: 'Number of running Docker containers',
  registers: [register]
});

const packageJsonCount = new client.Gauge({
  name: 'npm_package_json_count',
  help: 'Number of package.json files found',
  registers: [register]
});

// Function to get process information
function getProcessInfo(processName) {
  try {
    const output = execSync(
      `ps aux | grep ${processName} | grep -v grep`,
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
    );

    const processes = output.trim().split('\n').filter(line => line);
    const processData = processes.map(line => {
      const parts = line.split(/\s+/);
      return {
        pid: parts[1],
        cpu: parseFloat(parts[2]),
        mem: parseFloat(parts[3]),
        command: parts.slice(10).join(' ')
      };
    });

    return processData;
  } catch (error) {
    return [];
  }
}

// Function to get Docker container count
function getDockerContainerCount() {
  try {
    const output = execSync('docker ps -q | wc -l', { encoding: 'utf8' });
    return parseInt(output.trim());
  } catch (error) {
    return 0;
  }
}

// Function to count package.json files
function countPackageJsonFiles() {
  try {
    const output = execSync(
      'find /host/proc -name package.json 2>/dev/null | wc -l',
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] }
    );
    return parseInt(output.trim());
  } catch (error) {
    return 0;
  }
}

// Update metrics function
function updateMetrics() {
  // NPM processes
  const npmProcesses = getProcessInfo('npm');
  npmProcessCount.set(npmProcesses.length);

  npmProcesses.forEach(proc => {
    const memBytes = proc.mem * 1024 * 1024; // Convert to bytes (approximate)
    npmProcessMemory.set({ pid: proc.pid, command: proc.command }, memBytes);
    npmProcessCpu.set({ pid: proc.pid, command: proc.command }, proc.cpu);
  });

  // Node processes
  const nodeProcesses = getProcessInfo('node');
  nodeProcessCount.set(nodeProcesses.length);

  nodeProcesses.forEach(proc => {
    const memBytes = proc.mem * 1024 * 1024; // Convert to bytes (approximate)
    nodeProcessMemory.set({ pid: proc.pid, command: proc.command }, memBytes);
    nodeProcessCpu.set({ pid: proc.pid, command: proc.command }, proc.cpu);
  });

  // Docker containers
  dockerContainerCount.set(getDockerContainerCount());

  // Package.json count
  packageJsonCount.set(countPackageJsonFiles());
}

// Update metrics every 10 seconds
setInterval(updateMetrics, 10000);

// Initial metric update
updateMetrics();

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    const metrics = await register.metrics();
    res.end(metrics);
  } catch (error) {
    res.status(500).end(error.message);
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Root endpoint
app.get('/', (req, res) => {
  res.send(`
    <html>
      <head><title>NPM Exporter</title></head>
      <body>
        <h1>NPM/Node.js Prometheus Exporter</h1>
        <p><a href="/metrics">Metrics</a></p>
        <p><a href="/health">Health Check</a></p>
      </body>
    </html>
  `);
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`NPM Exporter listening on port ${PORT}`);
  console.log(`Metrics available at http://localhost:${PORT}/metrics`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  process.exit(0);
});
