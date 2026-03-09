# GymMore — production (Ubuntu 24, Docker)

Развёртывание на сервере Ubuntu 24: nginx, API, Postgres, Redis в Docker. Сайт — **gymmore.ru**, API — **api.gymmore.ru**. Доступ можно ограничить по IP и rate limit.

## Полная установка одной командой

На чистом сервере Ubuntu 24 (под пользователем с sudo):

```bash
curl -sSL https://raw.githubusercontent.com/duhmaster/fitapp/main/deployments/production/install.sh -o install.sh && sudo bash install.sh
```

Скрипт: ставит git и Docker (с устранением конфликтов репозитория), клонирует [репозиторий](https://github.com/duhmaster/fitapp) в `/opt/gymmore`, создаёт `.env` с сгенерированными паролями БД/Redis и JWT, при наличии Flutter собирает веб, запускает контейнеры и выполняет миграции. Переменные: `INSTALL_DIR=/opt/gymmore`, `REPO=https://github.com/duhmaster/fitapp`.

После установки: **сайт** — http://gymmore.ru, **API** — http://api.gymmore.ru, **админка** — http://adm.gymmore.ru (логин `admin`, пароль задаётся в `.env` как `ADMIN_PASSWORD`). Для HTTPS настройте сертификаты (см. ниже).

---

## Ручная установка

## Требования

- Ubuntu 24 (или аналог с Docker)
- SSH-доступ на сервер
- Домен (опционально, для HTTPS)

## 1. Установка Docker и Compose на сервере

Если Docker уже добавлялся ранее и появляется ошибка `Conflicting values set for option Signed-By`, сначала уберите **все** старые источники Docker (иначе остаётся запись без `Signed-By`, конфликтующая с новой):

```bash
# Удалить любые файлы в sources.list.d, где упоминается Docker
sudo grep -rl 'download.docker.com' /etc/apt/sources.list.d/ 2>/dev/null | xargs -r sudo rm -f
# Удалить строки с Docker из основного списка
sudo sed -i '/download\.docker\.com/d' /etc/apt/sources.list
sudo apt-get update
```

После этого ниже добавляется один источник с ключом в `/etc/apt/keyrings/docker.asc`.

Затем установите репозиторий и пакеты:

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a644 /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
# выйти и зайти по SSH снова, чтобы группа docker применилась
```

## 2. Клонирование репозитория и настройка

На сервере (или локально и копирование по SSH):

```bash
git clone https://github.com/duhmaster/fitapp /opt/gymmore  # или свой путь
cd /opt/gymmore
cp deployments/production/.env.example deployments/production/.env
# отредактировать deployments/production/.env: пароли, JWT_SECRET
```

Обязательно задать в `.env`:

- `DB_PASSWORD` — пароль Postgres
- `JWT_SECRET` — длинная случайная строка (≥32 символа)
- `CORS_ALLOWED_ORIGINS` — домен сайта (`https://gymmore.ru`)
- `STORAGE_BASE_URL` — URL загрузок (`https://api.gymmore.ru/uploads`)
- `ADMIN_PASSWORD` — пароль входа в админку (adm.gymmore.ru); если не задан, админка отключена

## 3. Сборка и размещение Flutter web

Локально (с установленным Flutter):

```bash
cd mobile && flutter build web && cd ..
cp -r mobile/build/web deployments/production/web
```

На сервер можно скопировать уже собранную папку `deployments/production/web` (например через `rsync`/`scp`).

## 4. Запуск

Все скрипты запускать **из корня репозитория** (например `/opt/gymmore`):

```bash
# Запуск стека
./scripts/production/start.sh

# Миграции (после первого запуска или после обновления кода с новыми миграциями)
./scripts/production/migrate.sh

# Остановка
./scripts/production/stop.sh

# Перезапуск
./scripts/production/restart.sh

# Обновление (пересборка API и перезапуск контейнеров)
./scripts/production/update.sh

# Логи (все сервисы или только api/nginx)
./scripts/production/logs.sh
./scripts/production/logs.sh api
```

При первом запуске имеет смысл после `start.sh` подождать ~20 секунд и выполнить `migrate.sh`.

## 5. Ограничение доступа (Flutter web и API)

- **Rate limit** уже включён в nginx: отдельные зоны для веба и API (см. `nginx/nginx.conf` и `nginx/conf.d/default.conf`).
- **Ограничение по IP**: в `nginx/conf.d/default.conf` раскомментировать блок `geo $api_allow` и указать разрешённые подсети/IP, затем раскомментировать строку `if ($api_allow = 0) { return 403; }` в `location /api/`. При необходимости можно добавить аналогичную логику для `location /` (веб-приложение).
- **HTTPS**: положить сертификаты в `deployments/production/nginx/ssl/` (например `fullchain.pem`, `privkey.pem`) и раскомментировать блок `server { listen 443 ssl ... }` в `nginx/conf.d/default.conf`, подставив свои пути к сертификатам.

## 6. Деплой с локальной машины по SSH

Пример однострочника (запуск на сервере после копирования кода):

```bash
rsync -avz --exclude '.git' --exclude 'mobile' ./ user@server:/opt/gymmore/ && \
ssh user@server 'cd /opt/gymmore && ./scripts/production/update.sh && ./scripts/production/migrate.sh'
```

Сборку Flutter web можно делать локально и копировать только `deployments/production/web` в `/opt/gymmore/deployments/production/web`.

## Структура

- `docker-compose.yml` — nginx, api, postgres, redis, сервис migrate (profile: tools).
- `nginx/` — конфиг nginx (прокси на API, раздача статики из `web`, rate limit, заготовка под ограничение по IP и HTTPS).
- `.env.example` — шаблон переменных; реальный `.env` не коммитить.
- Статика веба: каталог `web/` (переменная `WEB_ROOT` в `.env`), по умолчанию `./web` относительно каталога `deployments/production`.
