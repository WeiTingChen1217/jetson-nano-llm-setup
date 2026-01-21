#!/usr/bin/env bash

echo "停止 llama-server..."
pkill -f "llama-server.*--port 5001" || echo "llama-server 未執行"

echo "停止 SillyTavern..."
pkill -f "node.*server.js" || echo "SillyTavern 未執行"

echo "所有服務已停止。"
