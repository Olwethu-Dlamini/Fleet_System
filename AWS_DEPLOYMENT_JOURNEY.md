# ☁️ AWS Deployment Journey --- Polyglot OAuth System

## Overview

This document summarizes the deployment of a Polyglot Authentication
System consisting of: - Blazor WebAssembly Frontend - Node.js OAuth
Backend - Dockerized Microservices - AWS EC2 Free Tier Deployment -
DuckDNS Public Domain

------------------------------------------------------------------------

## System Architecture

Internet → DuckDNS → AWS EC2 → Docker Compose → Frontend (Nginx +
Blazor) & Backend (Node.js)

------------------------------------------------------------------------

## 1. AWS EC2 Setup

-   Instance: t2.micro (Free Tier)
-   OS: Ubuntu Server
-   Opened ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 5000 (API)
-   SSH restricted to My IP for security.

------------------------------------------------------------------------

## 2. SSH Access

Connected from Windows Bash: ssh -i key.pem ubuntu@`<elastic-ip>`{=html}

------------------------------------------------------------------------

## 3. Server Preparation

sudo apt update && sudo apt upgrade -y sudo apt install git docker.io -y
sudo systemctl enable docker sudo usermod -aG docker ubuntu

Installed Docker Compose plugin and verified installation.

------------------------------------------------------------------------

## 4. Project Deployment

git clone https://github.com/Olwethu-Dlamini/OAuth.git

------------------------------------------------------------------------

## 5. Missing .env Issue

Docker failed due to missing environment variables. Created node/.env
with: CLIENT_ID= CLIENT_SECRET= PORT=5000
CLIENT_ORIGIN_URL=http://oll1.duckdns.org
REDIRECT_URI=http://oll1.duckdns.org/auth/google/callback

------------------------------------------------------------------------

## 6. Domain Setup

Google OAuth rejected raw IP. Solution: Registered DuckDNS domain →
oll1.duckdns.org

------------------------------------------------------------------------

## 7. Docker Deployment

docker compose up -d --build

------------------------------------------------------------------------

## 8. Major Setback --- EC2 Build Freeze

Blazor WASM build froze for 40+ minutes. Cause: t2.micro insufficient
resources.

Lesson: Compile locally, run containers in EC2.

------------------------------------------------------------------------

## 9. New Deployment Strategy

Local Machine: dotnet publish -c Release

Generated publish/wwwroot and committed artifacts.

------------------------------------------------------------------------

## 10. Dockerfile Redesign

Frontend now serves static files using Nginx instead of building .NET
inside EC2.

------------------------------------------------------------------------

## 11. Docker Context Bug

COPY failed error fixed by correcting path to: publish/wwwroot

------------------------------------------------------------------------

## 12. OAuth Redirect Bug

Frontend still pointed to ngrok URL. Updated login link to:
http://oll1.duckdns.org/auth/google

------------------------------------------------------------------------

## 13. Container Debugging

Used: docker exec -it backend sh echo \$CLIENT_ORIGIN_URL

------------------------------------------------------------------------

## Final Working State

Frontend: http://oll1.duckdns.org

Backend Health: http://oll1.duckdns.org:5000/api/health

Google OAuth publicly operational.

------------------------------------------------------------------------

## Key Lessons

-   Small cloud instances should run workloads, not compile apps.
-   Docker build context matters.
-   OAuth requires public domains.
-   Security begins at firewall configuration.

------------------------------------------------------------------------

## Technologies Used

AWS EC2, Ubuntu, Docker, Docker Compose, Nginx, Node.js, Google OAuth
2.0, Blazor WebAssembly, DuckDNS.

------------------------------------------------------------------------

Author: Olwethu Dlamini Project: Polyglot Authentication System
