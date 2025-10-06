FROM node:18-alpine

# Install necessary tools for process monitoring
RUN apk add --no-cache \
    procps \
    docker-cli

# Create app directory
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies. Prefer a clean install when a lockfile exists, otherwise
# fall back to `npm install --production` to avoid CI failing when no lockfile
# is present in the repo.
RUN if [ -f package-lock.json ]; then \
      npm ci --only=production; \
    else \
      npm install --production; \
    fi

# Copy application code
COPY . .

# Expose metrics port
EXPOSE 9101

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:9101/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Run the exporter
CMD ["node", "index.js"]
