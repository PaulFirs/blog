#!/bin/bash

# Script for automatic blog deployment to a home server
# Usage: sudo ./deploy.sh

# Variables - CHANGE THEM TO YOURS
REPO_URL="https://github.com/yourusername/blog.git"
DEPLOY_DIR="/var/www/blog"
TEMP_DIR="/tmp/blog-deploy"
BACKUP_DIR="/var/www/blog-backups"

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting blog deployment...${NC}"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run this script with sudo${NC}"
    exit 1
fi

# Create backup directory
mkdir -p $BACKUP_DIR

# Remove temp directory if it exists
if [ -d "$TEMP_DIR" ]; then
    echo -e "${YELLOW}🗑️  Removing old temporary directory...${NC}"
    rm -rf $TEMP_DIR
fi

# Clone repository
echo -e "${GREEN}📦 Cloning repository...${NC}"
git clone $REPO_URL $TEMP_DIR

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Repository cloning failed${NC}"
    exit 1
fi

cd $TEMP_DIR

# Install dependencies
echo -e "${GREEN}📚 Installing dependencies...${NC}"
npm ci

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Dependency installation failed${NC}"
    exit 1
fi

# Build project
echo -e "${GREEN}🔨 Building project...${NC}"
npm run build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

# Create backup of current version
if [ -d "$DEPLOY_DIR" ]; then
    echo -e "${GREEN}💾 Creating backup of current version...${NC}"
    BACKUP_NAME="blog-backup-$(date +%Y%m%d-%H%M%S)"
    cp -r $DEPLOY_DIR $BACKUP_DIR/$BACKUP_NAME
    
    # Remove old backups (keep last 5)
    cd $BACKUP_DIR
    ls -t | tail -n +6 | xargs -r rm -rf
fi

# Remove old version
if [ -d "$DEPLOY_DIR" ]; then
    echo -e "${GREEN}🗑️  Removing old version...${NC}"
    rm -rf $DEPLOY_DIR
fi

# Copy new version
echo -e "${GREEN}📂 Copying new files...${NC}"
mkdir -p $(dirname $DEPLOY_DIR)
cp -r $TEMP_DIR/dist $DEPLOY_DIR

# Set correct permissions
echo -e "${GREEN}🔐 Setting permissions...${NC}"
chown -R www-data:www-data $DEPLOY_DIR
chmod -R 755 $DEPLOY_DIR

# Clean up temporary files
echo -e "${GREEN}🧹 Cleaning up...${NC}"
rm -rf $TEMP_DIR

# Reload Nginx (optional)
if command -v nginx &> /dev/null; then
    echo -e "${GREEN}🔄 Reloading Nginx...${NC}"
    nginx -t && systemctl reload nginx
fi

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${YELLOW}📍 Site is available at: $DEPLOY_DIR${NC}"
echo -e "${YELLOW}💾 Backups are stored in: $BACKUP_DIR${NC}"
