# 🚀 Quick Deployment Guide

## Quick Start

### 1. Install dependencies

```bash
npm install
```

### 2. Development

```bash
npm run dev
```

Open http://localhost:4321

### 3. Build

```bash
npm run build
```

Static files will be in the `dist/` folder

## 📦 Deploying to Home Server

### Option A: Manual Deploy

1. **Build the project:**
   ```bash
   npm run build
   ```

2. **Copy to server:**
   ```bash
   scp -r dist/* user@your-server:/var/www/blog/
   ```

3. **Configure Nginx** (see nginx.conf)

### Option B: Automatic Deploy

1. **Edit deploy.sh:**
   - Change `REPO_URL` to your repository URL
   - Check the `DEPLOY_DIR` paths

2. **Run deploy:**
   ```bash
   sudo ./deploy.sh
   ```

## ⚙️ Nginx Setup

1. **Copy config:**
   ```bash
   sudo cp nginx.conf /etc/nginx/sites-available/blog
   ```

2. **Edit the domain** in the config file

3. **Activate:**
   ```bash
   sudo ln -s /etc/nginx/sites-available/blog /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

## 🔐 SSL (Let's Encrypt)

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

## ✍️ Adding a Post

1. Create a file at `src/content/posts/my-article.md`
2. Add frontmatter:
   ```yaml
   ---
   title: "Title"
   description: "Description"
   date: 2025-01-28
   tags: ["tag1", "tag2"]
   ---
   ```
3. Write your content in Markdown
4. Commit and push

## 🎨 Project Colors

- **Primary**: #2C3E4F (dark blue)
- **Accent**: #D4A76A (gold)

Change in `src/styles/global.css`

## 🔧 Important Settings

Before deployment, make sure to change:

1. **astro.config.mjs** - `site: 'https://yourdomain.com'`
2. **deploy.sh** - `REPO_URL`
3. **nginx.conf** - `server_name`

## 📊 Structure

```
blog/
├── src/
│   ├── content/posts/     # Posts (Markdown)
│   ├── pages/             # Pages
│   ├── layouts/           # Layouts
│   ├── components/        # Components
│   └── styles/            # Styles
├── public/                # Static files
├── dist/                  # Build output (generated)
└── README.md              # Full documentation
```

## 🆘 Help

Full documentation in [README.md](README.md)

## ✅ Pre-deploy Checklist

- [ ] Domain changed in astro.config.mjs
- [ ] REPO_URL changed in deploy.sh
- [ ] server_name changed in nginx.conf
- [ ] favicon.svg added
- [ ] og-image.jpg added for social networks
- [ ] First posts created
- [ ] Local build tested (`npm run build`)
