# ===============================
# Base Node Image
# ===============================
FROM node:20-alpine

# Enforce UTC timezone for Node.js process — prevents date shift bugs when server TZ differs
ENV TZ=UTC

# Create working directory
WORKDIR /app

# Copy dependency files first
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy project files
COPY . .

# Expose API port
EXPOSE 3000

# Development startup
CMD ["npm", "run", "dev"]