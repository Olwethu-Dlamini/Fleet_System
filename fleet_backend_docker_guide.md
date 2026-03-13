# Fleet Management Backend Dockerization Guide

## Overview
This guide details all the steps taken to containerize the Vehicle Scheduling System Node.js backend, connect it to a MySQL database on the EC2 host, and make it accessible for the Flutter APK.

---

## 1. Project Structure
```
~/fleet/Fleet_System/
├── vehicle-scheduling-backend/  # Node.js backend
│   ├── src/server.js            # Main server file
│   ├── config/                  # Database and Swagger config
│   ├── routes/                  # API routes
│   ├── package.json
│   └── .env                     # Environment variables
└── vehicle_scheduling.sql       # Database dump
```

Your APK is on a phone and communicates with the Node.js backend via EC2 IP.

---

## 2. Dockerfile Creation
Inside `vehicle-scheduling-backend/`, create `Dockerfile`:

```dockerfile
# Base Node Image
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Copy dependency files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy all project files
COPY . .

# Expose backend port
EXPOSE 3000

# Start backend in development mode
CMD ["npm", "run", "dev"]
```

## 3. .dockerignore
```
node_modules
.git
.gitignore
.env
npm-debug.log
Dockerfile
docker-compose.yml
```

---

## 4. Building the Docker Image
```bash
docker build -t vehicle-backend .
```

Check images:
```bash
docker images
```

---

## 5. Running the Container (First Test)
```bash
docker run -d -p 3000:3000 --name vehicle_backend_dev vehicle-backend
```

Check logs:
```bash
docker logs vehicle_backend_dev
```
You will likely see a database connection error.

---

## 6. MySQL Networking Fix
1. MySQL listens only on localhost by default:
```bash
sudo ss -tulpn | grep 3306
```
Output shows `127.0.0.1:3306`.

2. Edit MySQL config:
```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
```
Change:
```
bind-address = 127.0.0.1
```
to:
```
bind-address = 0.0.0.0
```

3. Restart MySQL:
```bash
sudo systemctl restart mysql
```

---

## 7. Create Application Database User
Login to MySQL:
```bash
sudo mysql
```

Create user with proper password:
```sql
CREATE USER 'fleet_user'@'%' IDENTIFIED BY 'Fleet@2026Secure!';
GRANT ALL PRIVILEGES ON vehicle_scheduling.* TO 'fleet_user'@'%';
FLUSH PRIVILEGES;
EXIT;
```

> Note: Do NOT use root for production application access.

---

## 8. Update Backend `.env`
```env
DB_HOST=host.docker.internal
DB_USER=fleet_user
DB_PASSWORD=Fleet@2026Secure!
DB_NAME=vehicle_scheduling
DB_PORT=3306

PORT=3000
NODE_ENV=development
JWT_SECRET=vehicle_scheduling_secret_2024
JWT_EXPIRES=8h
```

---

## 9. Recreate Container with Host Network Access
```bash
docker stop vehicle_backend_dev
docker rm vehicle_backend_dev

docker run -d \
  -p 3000:3000 \
  --name vehicle_backend_dev \
  --env-file .env \
  --add-host=host.docker.internal:host-gateway \
  vehicle-backend
```

Check logs:
```bash
docker logs -f vehicle_backend_dev
```
Expected:
```
✅ Database connection successful
🚀 Vehicle Scheduling API
```

---

## 10. Flutter APK Connection
Inside the Flutter app, API calls should point to your EC2 public IP:
```text
http://EC2_PUBLIC_IP:3000
```
Localhost cannot be used from a phone.

---

## Architecture After Setup
```
Flutter APK
      ↓
EC2 Port 3000
      ↓
Docker Container (Node.js API)
      ↓
MySQL (fleet_user)
```

This is a **clean, production-ready structure** with limited DB user access.

---

## Next Steps (Optional)
- Create `docker-compose.yml` to manage multiple services
- Add auto-restart and logging
- Use Nginx as reverse proxy
- Setup HTTPS
- Setup GitHub auto-deployment

This setup ensures your backend is containerized, secure, and accessible from external clients like your Flutter APK.

