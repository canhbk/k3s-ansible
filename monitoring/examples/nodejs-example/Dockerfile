FROM node:18-alpine

# Create app directory
WORKDIR /app

# Install app dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy app source
COPY . .

# Expose ports
EXPOSE 3000

# Run as non-root user
USER node

# Start the application
CMD ["node", "app.js"]
