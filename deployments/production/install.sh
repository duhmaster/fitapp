#!/usr/bin/env bash
# Полная установка GymMore на Ubuntu 24: зависимости, клон репо, .env, Docker, миграции.
# Сайт: gymmore.ru, API: api.gymmore.ru
#
# Запуск (на сервере):
#   curl -sSL https://raw.githubusercontent.com/duhmaster/fitapp/main/deployments/production/install.sh -o install.sh && sudo bash install.sh
# или после клонирования репо:
#   sudo ./deployments/production/install.sh
#
# Переменные: INSTALL_DIR=/opt/gymmore  REPO=https://github.com/duhmaster/fitapp

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-/opt/gymmore}"
REPO="${REPO:-https://github.com/duhmaster/fitapp}"
# Если скрипт запущен из репо (deployments/production/install.sh), используем корень репо
if [[ -f "$SCRIPT_DIR/docker-compose.yml" ]]; then
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
  PROJECT_ROOT=""
fi

log() { echo "[install] $*"; }
err() { echo "[install] ERROR: $*" >&2; }

# --- 1. Установка пакетов (git, Docker) ---
install_packages() {
  log "Обновление apt и установка git, curl, ca-certificates..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq ca-certificates curl git

  # Убрать конфликтующие источники Docker
  if sudo grep -rl 'download.docker.com' /etc/apt/sources.list.d/ 2>/dev/null; then
    log "Удаление старых настроек Docker..."
    sudo grep -rl 'download.docker.com' /etc/apt/sources.list.d/ 2>/dev/null | xargs -r sudo rm -f
    sudo sed -i '/download\.docker\.com/d' /etc/apt/sources.list
  fi

  if ! command -v docker &>/dev/null; then
    log "Установка Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a644 /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    log "Docker установлен."
  else
    log "Docker уже установлен."
  fi

  # Добавить текущего пользователя в группу docker (если не root)
  if [[ -n "${SUDO_USER:-}" ]]; then
    sudo usermod -aG docker "$SUDO_USER" 2>/dev/null || true
  fi
}

# --- 2. Клонирование репозитория ---
ensure_repo() {
  if [[ -n "$PROJECT_ROOT" ]] && [[ -d "$PROJECT_ROOT/.git" ]] && [[ -f "$PROJECT_ROOT/deployments/production/docker-compose.yml" ]]; then
    log "Используется текущий репозиторий: $PROJECT_ROOT"
    return
  fi
  if [[ -d "$INSTALL_DIR/.git" ]] && [[ -f "$INSTALL_DIR/deployments/production/docker-compose.yml" ]]; then
    PROJECT_ROOT="$INSTALL_DIR"
    log "Используется существующий репозиторий: $PROJECT_ROOT"
    return
  fi
  sudo mkdir -p "$(dirname "$INSTALL_DIR")"
  if [[ -d "$INSTALL_DIR" ]]; then
    err "Каталог $INSTALL_DIR существует, но не похож на репо. Удалите его или задайте INSTALL_DIR."
    exit 1
  fi
  log "Клонирование $REPO в $INSTALL_DIR..."
  sudo git clone --depth 1 "$REPO" "$INSTALL_DIR"
  PROJECT_ROOT="$INSTALL_DIR"
  if [[ -n "${SUDO_USER:-}" ]]; then
    sudo chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR"
  fi
}

# --- 3. Создание .env с учётами БД/Redis и доменами ---
create_env() {
  local env_file="$PROJECT_ROOT/deployments/production/.env"
  if [[ -f "$env_file" ]]; then
    log "Файл .env уже есть, пропуск генерации. Проверьте CORS_ALLOWED_ORIGINS и STORAGE_BASE_URL."
    return
  fi
  log "Генерация .env и паролей..."
  local db_pass jwt_secret redis_pass
  db_pass="$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)"
  jwt_secret="$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 48)"
  redis_pass="$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)"

  sudo tee "$env_file" > /dev/null << ENV
# Сгенерировано install.sh. Сайт: gymmore.ru, API: api.gymmore.ru
HTTP_PORT=80
HTTPS_PORT=443
WEB_ROOT=./web

DB_NAME=gymmore
DB_USER=gymmore
DB_PASSWORD=$db_pass
DB_SSLMODE=require

REDIS_PASSWORD=$redis_pass

JWT_SECRET=$jwt_secret
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=168h

STORAGE_BASE_URL=https://api.gymmore.ru/uploads
CORS_ALLOWED_ORIGINS=https://gymmore.ru
ENV
  sudo chmod 600 "$env_file"
  if [[ -n "${SUDO_USER:-}" ]]; then
    sudo chown "$SUDO_USER:$SUDO_USER" "$env_file"
  fi
  log "Пароли и JWT записаны в $env_file (сохраните пароль БД и Redis при необходимости)."
}

# --- 4. Статика Flutter (сборка или заглушка) ---
prepare_web() {
  local web_dir="$PROJECT_ROOT/deployments/production/web"
  sudo mkdir -p "$web_dir"
  if command -v flutter &>/dev/null; then
    log "Сборка Flutter web..."
    ( cd "$PROJECT_ROOT/mobile" && flutter build web )
    sudo cp -r "$PROJECT_ROOT/mobile/build/web/"* "$web_dir/"
    log "Flutter web скопирован в $web_dir"
  else
    if [[ ! -f "$web_dir/index.html" ]]; then
      echo '<!DOCTYPE html><html><head><meta charset="utf-8"><title>GymMore</title></head><body>Place Flutter build here: <code>cd mobile && flutter build web && cp -r build/web/* '"$web_dir"'/</code></body></html>' | sudo tee "$web_dir/index.html" > /dev/null
      log "Создана заглушка в $web_dir. Позже замените на сборку Flutter."
    fi
  fi
  if [[ -n "${SUDO_USER:-}" ]]; then
    sudo chown -R "$SUDO_USER:$SUDO_USER" "$web_dir"
  fi
}

# --- 5. Запуск Docker и миграции ---
start_stack_and_migrate() {
  cd "$PROJECT_ROOT"
  local compose_file="deployments/production/docker-compose.yml"
  local env_file="deployments/production/.env"

  log "Запуск Docker Compose (build + up)..."
  sudo docker compose -f "$compose_file" --env-file "$env_file" build --no-cache api
  sudo docker compose -f "$compose_file" --env-file "$env_file" up -d

  log "Ожидание готовности Postgres и Redis..."
  for i in $(seq 1 60); do
    if sudo docker compose -f "$compose_file" --env-file "$env_file" exec -T postgres pg_isready -U gymmore -d gymmore 2>/dev/null; then
      break
    fi
    [[ $i -eq 60 ]] && { err "Postgres не поднялся."; exit 1; }
    sleep 1
  done
  for i in $(seq 1 30); do
    if sudo docker compose -f "$compose_file" --env-file "$env_file" exec -T redis redis-cli ping 2>/dev/null | grep -q PONG; then
      break
    fi
    [[ $i -eq 30 ]] && { err "Redis не поднялся."; exit 1; }
    sleep 1
  done

  log "Выполнение миграций..."
  set -a
  # shellcheck source=/dev/null
  source "$env_file"
  set +a
  local dsn="postgres://${DB_USER:-gymmore}:${DB_PASSWORD}@postgres:5432/${DB_NAME:-gymmore}?sslmode=${DB_SSLMODE:-require}"
  sudo docker compose -f "$compose_file" --env-file "$env_file" run --rm --profile tools -e "MIGRATE_DSN=$dsn" migrate sh -c 'migrate -path /migrations -database "$MIGRATE_DSN" up'

  log "Готово."
}

# --- main ---
main() {
  log "Старт полной установки GymMore (gymmore.ru / api.gymmore.ru)"
  install_packages
  ensure_repo
  create_env
  prepare_web
  start_stack_and_migrate
  echo ""
  echo "  Сайт (Flutter):  http://gymmore.ru"
  echo "  API:             http://api.gymmore.ru"
  echo "  Здоровье API:   http://api.gymmore.ru/health"
  echo ""
  echo "  Управление: cd $PROJECT_ROOT && ./scripts/production/start.sh | stop.sh | logs.sh | migrate.sh"
  echo "  Для HTTPS настройте сертификаты и раскомментируйте блоки server { listen 443 } в deployments/production/nginx/conf.d/default.conf"
}

main "$@"
