# Блог на Astro

Минималистичный, быстрый блог на Astro с поддержкой Markdown, поиска, RSS и SEO.

## 🚀 Структура проекта

```
/
├── public/              # Статические файлы (favicon, изображения)
├── src/
│   ├── components/      # Компоненты Astro
│   │   ├── SEO.astro    # SEO метатеги
│   │   └── Search.astro # Клиентский поиск
│   ├── content/         # Коллекции контента
│   │   ├── config.ts    # Схема контента
│   │   └── posts/       # Markdown статьи
│   ├── layouts/         # Layouts
│   │   └── Layout.astro # Основной layout
│   ├── pages/           # Страницы и роуты
│   │   ├── index.astro
│   │   ├── blog/
│   │   │   ├── index.astro      # Список статей
│   │   │   ├── [slug].astro     # Отдельная статья
│   │   │   └── tags/[tag].astro # Фильтр по тегу
│   │   └── rss.xml.js   # RSS лента
│   └── styles/
│       └── global.css   # Глобальные стили
├── astro.config.mjs
├── package.json
└── tsconfig.json
```

## 📝 Добавление новой статьи

1. Создайте новый `.md` файл в `src/content/posts/`
2. Добавьте frontmatter:

```markdown
---
title: "Заголовок статьи"
description: "Краткое описание"
date: 2025-01-28
tags: ["javascript", "astro"]
---

## Ваш контент здесь

Пишите статью в Markdown...
```

3. Закоммитьте и запушьте изменения на GitHub

## 🛠️ Команды

| Команда               | Описание                                   |
| --------------------- | ------------------------------------------ |
| `npm install`         | Установка зависимостей                     |
| `npm run dev`         | Запуск dev сервера на `localhost:4321`     |
| `npm run build`       | Сборка в `./dist/`                         |
| `npm run preview`     | Предпросмотр собранного сайта              |

## 🎨 Цветовая схема

- **Primary (Фон, текст)**: `#2C3E4F` — темно-синий/угольный
- **Accent (Акценты)**: `#D4A76A` — песочный/золотой
- **Background**: `#1a252f` — темный фон
- **Text**: `#e4e4e4` — светлый текст

## 🔧 Настройка перед развертыванием

1. В `astro.config.mjs` измените `site` на ваш домен:

```javascript
export default defineConfig({
  site: 'https://yourdomain.com',
  // ...
});
```

2. Добавьте favicon в `public/favicon.svg`
3. Добавьте og-image в `public/og-image.jpg` для соцсетей

## 🏠 Развертывание на домашнем сервере

### Метод 1: Nginx (рекомендуется)

#### 1. Сборка проекта

```bash
npm run build
```

Это создаст папку `dist/` со всеми статическими файлами.

#### 2. Конфигурация Nginx

Создайте файл `/etc/nginx/sites-available/blog`:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    root /var/www/blog;
    index index.html;

    # Сжатие
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/javascript application/json;

    # Кэширование статических ресурсов
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Поддержка чистых URL
    location / {
        try_files $uri $uri/ $uri.html =404;
    }

    # Безопасность
    add_header X-Frame-Options "SAMEORIGIN" always;
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
        /* Lines 102-129 omitted */
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
Блог включает:
- ✅ Семантический HTML
- ✅ Meta теги (title, description)
- ✅ Open Graph для соцсетей
- ✅ Twitter Cards
- ✅ RSS лента (`/rss.xml`)
- ✅ Sitemap (генерируется автоматически)
- ✅ Чистые URL

## ⚡ Производительность

- **Статическая генерация** — мгновенная загрузка
- **Нулевой JavaScript** (кроме поиска)
- **Оптимизация изображений** — используйте WebP
- **CSS инлайнинг** — критические стили
- **Gzip сжатие** — через Nginx

## 📱 Адаптивность

Дизайн полностью адаптивен для всех устройств.

## 🎯 Дальнейшие улучшения

- [ ] Комментарии через Giscus
- [ ] Аналитика (например, Plausible)
- [ ] Dark/Light режим
- [ ] Таблица содержания для статей
- [ ] Время чтения
- [ ] Связанные статьи
- [ ] Пагинация

## 📄 Лицензия

MIT

## 🤝 Вклад

Pull requests приветствуются!
