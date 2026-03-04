# ===============================
# Base Node Image
# ===============================
FROM node:20-alpine

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