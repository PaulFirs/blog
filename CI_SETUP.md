# 🚀 CI Deployment Setup

## Quick setup for home server deployment

### 1. Server Setup

On your server, run:

```bash
# Create directory for the site
sudo mkdir -p /var/www/blog
sudo chown $USER:$USER /var/www/blog

# Install nginx (if not already installed)
sudo apt update && sudo apt install nginx -y
```

### 2. Setup SSH Keys

On your server, generate SSH key pair:

```bash
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
cat ~/.ssh/id_ed25519  # Copy this output
```

### 3. Configure GitHub Secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add:

- `SSH_PRIVATE_KEY` - paste the private key from previous step
- `REMOTE_HOST` - IP address of your server (e.g., `192.168.1.199`) or domain
- `REMOTE_USER` - username on your server (e.g., `paul`)

### 4. Enable HTTPS (free SSL certificate)

Get a free SSL certificate from Let's Encrypt:

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx -y

# Get and configure SSL certificate (automatic)
sudo certbot --nginx -d paulfirs.com
```

Certbot will automatically:
- Obtain a free SSL certificate
- Configure Nginx for HTTPS
- Set up automatic certificate renewal (every 90 days)

### 5. Done!

Now every push to `main` will automatically:
- Build the site
- Deploy files to `/var/www/blog`
- Configure Nginx (first time only)

You can also trigger deployment manually via **Actions → Deploy to Home Server → Run workflow**

**Note:** Nginx is configured automatically on first deploy. For HTTPS, run step 4 manually on the server once.

## Verification

After deployment, your site will be available at: https://paulfirs.com
