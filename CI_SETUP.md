# 🚀 CI Deployment Setup

## Quick setup for home server deployment (Self-Hosted Runner)

### 1. Server Setup

On your server, run:

```bash
# Create directory for the site
sudo mkdir -p /var/www/blog
sudo chown $USER:$USER /var/www/blog

# Install nginx (if not already installed)
sudo apt update && sudo apt install nginx -y

# Allow runner user to run commands without password
echo "$USER ALL=(ALL) NOPASSWD: /bin/cp, /bin/mkdir, /bin/chown, /usr/sbin/nginx, /bin/systemctl, /bin/ln" | sudo tee /etc/sudoers.d/github-runner
sudo chmod 440 /etc/sudoers.d/github-runner
```

### 2. Install GitHub Runner on Server

1. Go to your GitHub repo → **Settings → Actions → Runners → New self-hosted runner**
2. Follow the commands shown on the page (they look like this):

```bash
# Download
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64-2.xxx.x.tar.gz -L https://github.com/actions/runner/releases/download/vX.XXX.X/actions-runner-linux-x64-2.XXX.X.tar.gz
tar xzf ./actions-runner-linux-x64-2.xxx.x.tar.gz

# Configure
./config.sh --url https://github.com/YOUR_USERNAME/blog --token YOUR_TOKEN

# Install as service (runs in background)
sudo ./svc.sh install
sudo ./svc.sh start
```

### 3. Enable HTTPS (free SSL certificate)

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

### 4. Done!

Now every push to `main` will automatically:
- Build the site on your server
- Deploy files to `/var/www/blog`
- Configure Nginx (first time only)

You can also trigger deployment manually via **Actions → Deploy to Home Server → Run workflow**

**Note:** No port forwarding needed! Runner works locally on your server.

## Verification

After deployment, your site will be available at: https://paulfirs.com
