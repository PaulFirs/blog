# Astro Blog

A minimalist, fast blog on Astro with Markdown, search, RSS, and SEO support.

## 🚀 Project Structure

```
/
├── public/              # Static files (favicon, images)
├── src/
│   ├── components/      # Astro components
│   │   ├── SEO.astro    # SEO meta tags
│   │   └── Search.astro # Client-side search
│   ├── content/         # Content collections
│   │   ├── config.ts    # Content schema
│   │   └── posts/       # Markdown posts
│   ├── layouts/         # Layouts
│   │   └── Layout.astro # Main layout
│   ├── pages/           # Pages and routes
│   │   ├── index.astro
│   │   ├── blog/
│   │   │   ├── index.astro      # Post list
│   │   │   ├── [slug].astro     # Single post
│   │   │   └── tags/[tag].astro # Tag filter
│   │   └── rss.xml.js   # RSS feed
│   └── styles/
│       └── global.css   # Global styles
├── astro.config.mjs
├── package.json
└── tsconfig.json
```

## 📝 Adding a New Post

1. Create a new `.md` file in `src/content/posts/`
2. Add frontmatter:

```markdown
---
title: "Post Title"
description: "Short description"
date: 2025-01-28
tags: ["javascript", "astro"]
---

## Your content here

Write your post in Markdown...
```

3. Commit and push changes to GitHub

## 🛠️ Commands

| Command               | Description                                 |
| --------------------- | ------------------------------------------- |
| `npm install`         | Install dependencies                        |
| `npm run dev`         | Start dev server at `localhost:4321`        |
| `npm run build`       | Build to `./dist/`                          |
| `npm run preview`     | Preview the built site                      |

## 🎨 Color Scheme

- **Primary (Background, text)**: `#2C3E4F` — dark blue/charcoal
- **Accent**: `#D4A76A` — sand/gold
- **Background**: `#1a252f` — dark background
- **Text**: `#e4e4e4` — light text

## 🔧 Pre-deployment Setup

1. In `astro.config.mjs` change `site` to your domain:

```javascript
export default defineConfig({
  site: 'https://yourdomain.com',
  // ...
});
```

2. Add favicon to `public/favicon.svg`
3. Add og-image to `public/og-image.jpg` for social networks

## 🏠 Deploying to Home Server

### Method 1: Nginx (recommended)

#### 1. Build the project

```bash
npm run build
```

This will create the `dist/` folder with all static files.

#### 2. Nginx configuration

Create the file `/etc/nginx/sites-available/blog`:

```nginx
server {
  listen 80;
  server_name yourdomain.com www.yourdomain.com;

  root /var/www/blog;
  index index.html;

  # Compression
  gzip on;
  gzip_vary on;
  gzip_min_length 1024;
  gzip_types text/plain text/css text/xml text/javascript 
         application/x-javascript application/xml+rss 
         application/javascript application/json;

  # Static resource caching
  location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }

  # Clean URLs support
  location / {
    try_files $uri $uri/ $uri.html =404;
  }

  # Security
  add_header X-Frame-Options "SAMEORIGIN" always;
  add_header X-XSS-Protection "1; mode=block" always;
}
```

#### 3. Activate configuration

```bash
sudo ln -s /etc/nginx/sites-available/blog /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### 4. SSL with Let's Encrypt (optional, but recommended)

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### Method 2: Automatic Deploy from GitHub

#### Deploy script

Create a file `deploy.sh` in the project root:

```bash
#!/bin/bash

# Variables
REPO_URL="https://github.com/yourusername/blog.git"
DEPLOY_DIR="/var/www/blog"
TEMP_DIR="/tmp/blog-deploy"

echo "🚀 Starting deploy..."

# Clone repository
echo "📦 Cloning repository..."
rm -rf $TEMP_DIR
git clone $REPO_URL $TEMP_DIR
```

The blog includes:
- ✅ Semantic HTML
- ✅ Meta tags (title, description)
- ✅ Open Graph for social networks
- ✅ Twitter Cards
- ✅ RSS feed (`/rss.xml`)
- ✅ Sitemap (generated automatically)
- ✅ Clean URLs

## ⚡ Performance

- **Static generation** — instant loading
- **Zero JavaScript** (except search)
- **Image optimization** — use WebP
- **CSS inlining** — critical styles
- **Gzip compression** — via Nginx

## 📱 Responsiveness

The design is fully responsive for all devices.

## 🎯 Further Improvements

- [ ] Comments via Giscus
- [ ] Analytics (e.g., Plausible)
- [ ] Dark/Light mode
- [ ] Table of contents for posts
- [ ] Reading time
- [ ] Related posts
- [ ] Pagination

## 📄 License

MIT

## 🤝 Contributing

Pull requests are welcome!
