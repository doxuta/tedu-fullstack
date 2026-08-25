#!/usr/bin/env bash
# Bật toàn bộ môi trường dev TEdu trong 1 lệnh
set -e
cd "$(dirname "$0")/.."
echo "▸ Bật PostgreSQL (Docker)..."
docker compose up -d
echo "▸ Cài & chạy backend..."
cd server
[ -f .env ] || cp .env.example .env
[ -d node_modules ] || npm install
npm run db:migrate
echo "▸ Server: http://localhost:8787 — Ctrl+C để dừng"
npm run dev
