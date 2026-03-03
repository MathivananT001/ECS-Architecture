# Node.js Application

A simple serverless Node.js application that runs on AWS ECS Fargate.

## What It Does

- Serves a "Hello World" web page on port 8080
- Provides a `/health` endpoint for health checks
- Displays container information (hostname, time, etc.)
- Uses Express.js for HTTP handling
- Includes Docker multi-stage build for minimal image size

## Building the Docker Image

### Prerequisites
- Docker installed locally
- AWS CLI configured
- AWS account with ECR access

### Build Steps

1. **Build the Docker image locally:**
   ```bash
   cd app
   docker build -t serverless-app:latest .
   ```

2. **Test locally (optional):**
   ```bash
   docker run -p 8080:8080 serverless-app:latest
   # Visit http://localhost:8080 in your browser
   ```

3. **Get ECR repository URL:**
   ```bash
   terraform output ecr_repository_url
   ```

4. **Login to ECR:**
   ```bash
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <REPOSITORY_URL>
   ```

5. **Tag the image:**
   ```bash
   docker tag serverless-app:latest <REPOSITORY_URL>:latest
   ```

6. **Push to ECR:**
   ```bash
   docker push <REPOSITORY_URL>:latest
   ```

## Environment Variables

- `PORT` - Server listening port (default: 8080)
- `NODE_ENV` - Node environment (default: production)

## Health Endpoint

The application includes a health check endpoint:
- URL: `GET /health`
- Response: `{ "status": "healthy" }`
- Used by ALB for target health checks

## Main Endpoint

- URL: `GET /`
- Response: HTML page with "Hello World" message and service info
- Displays: Service name, platform, port, timestamp, hostname

## Dockerfile Details

- **Base Image:** node:18-alpine (lightweight)
- **Build Stage:** Installs dependencies
- **Runtime Stage:** Copies only necessary files (size optimized)
- **Health Check:** Docker health check configured
- **Expose:** Port 8080

## Image Size

- Final image: ~150MB (optimized with multi-stage build)
