#!/usr/bin/env bash

# start-all.sh
# 用法：在 ~/Documents/llama 目錄下執行：./start-all.sh
# 功能：啟動 llama-server + SillyTavern，背景執行並記錄 log

set -e  # 遇到錯誤就停止執行

# ========================
# 設定區（可自行修改）
# ========================

LLAMA_DIR="$HOME/Documents/llama/llama5050gpu.cpp"
LLAMA_BUILD="$LLAMA_DIR/build"
MODEL_PATH="$HOME/Documents/llama/models/qwen2.5-coder-3b-instruct-q4_k_m.gguf"
LLAMA_PORT=5001
LLAMA_LOG="$HOME/Documents/llama/llama-server.log"

SILLY_DIR="$HOME/Documents/llama/SillyTavern"
SILLY_LOG="$HOME/Documents/llama/sillytavern.log"

# ========================
# 檢查必要條件
# ========================

if [ ! -f "$MODEL_PATH" ]; then
    echo "錯誤：模型檔案不存在 → $MODEL_PATH"
    exit 1
fi

if [ ! -d "$LLAMA_BUILD" ] || [ ! -x "$LLAMA_BUILD/bin/llama-server" ]; then
    echo "錯誤：llama-server 可執行檔不存在 → $LLAMA_BUILD/bin/llama-server"
    exit 1
fi

if [ ! -d "$SILLY_DIR" ] || [ ! -f "$SILLY_DIR/server.js" ]; then
    echo "錯誤：SillyTavern 資料夾或 server.js 不存在 → $SILLY_DIR"
    exit 1
fi

# ========================
# 檢查是否已經在執行
# ========================

if pgrep -f "llama-server.*--port $LLAMA_PORT" > /dev/null; then
    echo "llama-server 似乎已經在執行中 (port $LLAMA_PORT)，跳過啟動。"
else
    echo "啟動 llama-server..."
    cd "$LLAMA_BUILD" || { echo "無法 cd 到 $LLAMA_BUILD"; exit 1; }
    nohup ./bin/llama-server \
        -m "$MODEL_PATH" \
        --n-gpu-layers 50 \
        -c 4096 \
        --port "$LLAMA_PORT" \
        --host 0.0.0.0 \
        --jinja > "$LLAMA_LOG" 2>&1 &
    echo "llama-server 已啟動，log 在 $LLAMA_LOG"
    echo "PID: $!"
fi

sleep 3  # 給 llama-server 一點時間啟動

if pgrep -f "node.*server.js" > /dev/null; then
    echo "SillyTavern (node server.js) 似乎已經在執行中，跳過啟動。"
else
    echo "啟動 SillyTavern..."
    cd "$SILLY_DIR" || { echo "無法 cd 到 $SILLY_DIR"; exit 1; }
    nohup node server.js > "$SILLY_LOG" 2>&1 &
    echo "SillyTavern 已啟動，log 在 $SILLY_LOG"
    echo "PID: $!"
fi

echo ""
echo "所有服務啟動完成！"
echo "檢查狀態："
echo "  tail -f $LLAMA_LOG"
echo "  tail -f $SILLY_LOG"
echo ""
echo "網頁介面："
echo "  本機：          http://localhost:8000/"
echo "  區域網路：      http://$(hostname -I | awk '{print $1}'):8000/"
echo ""
echo "API 端點：        http://localhost:$LLAMA_PORT/v1"
