# AWS IoT Realtime Data Pipeline

A cloud-native, event-driven IoT data pipeline built with MQTT, AWS infrastructure, Terraform, and a real-time monitoring dashboard.

## Overview

This project is designed to collect, process, and visualize IoT device telemetry in real time using a modern cloud architecture.

IoT devices publish telemetry messages through MQTT. Incoming messages are routed through the cloud infrastructure, processed by backend services, and delivered to a real-time dashboard for monitoring and visualization.

The project follows a monorepo architecture, separating frontend applications, backend services, and infrastructure configuration.

## Architecture

The intended production architecture uses AWS-managed services for IoT connectivity, event processing, and monitoring:

1. **IoT Devices / Simulator:** Generates telemetry data.
2. **AWS IoT Core:** Manages MQTT connectivity and message routing.
3. **AWS IoT Rules:** Routes messages to downstream services.
4. **AWS Lambda:** Processes and transforms telemetry events.
5. **Backend API (WebSocket):** Distributes real-time updates.
6. **React Dashboard:** Visualizes incoming data.
7. **Amazon CloudWatch:** Provides logging and monitoring.

> **Note:** The live demo on Vercel uses simulated data. The full MQTT/AWS pipeline runs in the local environment.

## Technology Stack

| Layer | Technology |
| :--- | :--- |
| IoT Protocol | MQTT |
| Cloud Infrastructure | AWS IoT Core, AWS Lambda, CloudWatch |
| Infrastructure as Code | Terraform |
| Backend | Node.js, TypeScript, Express, WebSocket, MQTT.js |
| Frontend | React, Vite, TypeScript |
| Local MQTT Broker | Eclipse Mosquitto |
| Containerization | Docker |

## Repository Structure

```text
mqtt-iot-pipeline/
├── apps/
│   └── dashboard/          # React frontend (Vite)
├── services/
│   ├── api-server/         # Node.js Express API & WebSocket
│   └── publisher/          # Node.js MQTT Publisher (Simulator)
├── terraform/              # AWS Infrastructure as Code
├── mosquitto.conf          # Local MQTT broker configuration
└── package.json            # Monorepo workspace configuration
```

## Local Development

### Prerequisites

- Node.js v18 or later
- Docker
- npm

### Quick Start

**1. Start the MQTT Broker**

```bash
docker run -d \
  --name mqtt-broker \
  -p 1883:1883 \
  -p 9001:9001 \
  -v "$(pwd)/mosquitto.conf:/mosquitto/config/mosquitto.conf" \
  eclipse-mosquitto
```

**2. Install Dependencies**

```bash
npm install
```

**3. Run the Services**

Run each service in a separate terminal.

```bash
# Terminal 1: API Server
npm run dev:api

# Terminal 2: MQTT Publisher
npm run dev:publisher

# Terminal 3: Dashboard
npm run dev:dashboard
```

**4. Access the Dashboard**

Open the following URL in your browser:

```text
http://localhost:5173
```

## Infrastructure as Code

The `terraform/` directory contains Terraform configurations for provisioning the AWS infrastructure.

Initialize and validate the configuration:

```bash
cd terraform

terraform init
terraform validate
terraform plan
```

> **Note:** Provisioning AWS resources with `terraform apply` requires valid AWS credentials and may incur additional cloud costs.

## Live Demo

**Dashboard:** https://mqtt-iot-dashboard-cyctam.vercel.app

The live demo uses simulated telemetry data for demonstration purposes.

## Key Engineering Focus

- Event-driven architecture using MQTT.
- Real-time telemetry ingestion and visualization.
- Infrastructure as Code with Terraform.
- Containerized local MQTT broker using Docker.
- Backend communication using WebSocket.
- Cloud infrastructure integration with AWS services.
- Separation of frontend, backend, and infrastructure components.
