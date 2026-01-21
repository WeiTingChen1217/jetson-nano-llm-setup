# Jetson Nano 本地 LLM 部署紀錄（Qwen2.5-Coder + SillyTavern 網頁介面）

**系統環境**  
- 硬體：Jetson Nano 4GB  
- 系統：JetPack 4.6.6 / L4T 32.7.6 / Ubuntu 18.04  
- 目標：使用 llama.cpp 運行 Qwen2.5-Coder 系列模型，並透過 SillyTavern 提供網頁聊天介面（支援文件上傳 / RAG）

**最終使用模型**  
- Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf（約 2GB，tg ≈ 5–9 tok/s）  
- 備用：Qwen2.5-Coder-1.5B-Instruct-Q5_K_M.gguf

**專案目錄結構**  
```
~/Documents/llama/
├── llama5050gpu.cpp/          # llama.cpp fork (CUDA 支援 Jetson Nano)
│   └── build/
│       └── bin/
│           ├── llama-cli
│           └── llama-server
├── models/                    # 模型檔案
│   ├── qwen2.5-coder-1.5b-instruct-q5_k_m.gguf
│   └── qwen2.5-coder-3b-instruct-q4_k_m.gguf
├── SillyTavern/               # 網頁聊天介面
│   ├── server.js
│   ├── config.yaml
│   └── sillytavern.log
└── README.md                  # 本文件
```

## 安裝步驟總覽

### 1. 準備環境與工具
```bash
mkdir ~/Documents/llama && cd ~/Documents/llama

# 安裝基本工具
sudo apt update
sudo apt install -y nano curl libcurl4-openssl-dev python3-pip build-essential software-properties-common libgmp-dev libmpfr-dev libmpc-dev libssl-dev

# 升級 cmake 到 3.27（舊版 cmake 不支援某些參數）
wget https://cmake.org/files/v3.27/cmake-3.27.1.tar.gz
tar -xzvf cmake-3.27.1.tar.gz
cd cmake-3.27.1
./bootstrap
make -j4
sudo make install
cd ..

# 安裝 gcc-8（llama.cpp 需要較新 gcc）
sudo apt install -y gcc-8 g++-8
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 80 --slave /usr/bin/g++ g++ /usr/bin/g++-8
```

### 2. 下載並編譯 llama.cpp（CUDA 支援 Jetson Nano）
```bash
git clone https://github.com/ggml-org/llama.cpp llama5050gpu.cpp
cd llama5050gpu.cpp
git checkout b5773                  # 這個 commit 在 Nano 上較穩定
git checkout -b llamaJetsonNanoCUDA

mkdir build && cd build

# 編譯（重點參數：CUDA + sm_53 + curl）
cmake .. \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES=53 \
  -DLLAMA_CURL=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CUDA_STANDARD=14

make -j4
```

**常見問題與修正**  
- 參考網頁: https://github.com/kreier/llama.cpp-jetson/tree/b5050?tab=readme-ov-file

### 3. 下載模型
```bash
# 模型放這裡：~/Documents/llama/models/
# 下載 qwen2.5-coder-3b-instruct-q4_k_m.gguf（推薦）
# 來源：Hugging Face Qwen/Qwen2.5-Coder-3B-Instruct-GGUF 或 unsloth fork
```

### 4. 測試 llama.cpp
```bash
# 單次測試
./build/bin/llama-cli \
  -m ../models/Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf \
  --n-gpu-layers 50 \
  -c 2048 -b 128 -t 4 \
  -p "寫一個 Python Flask API，支持用戶註冊/登入，並用 JWT 驗證" \
  -n 512 --color

# benchmark
./build/bin/llama-bench \
  -m ../models/Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf \
  --n-gpu-layers 50 -p 512 -n 128
```

### 5. 啟動 llama-server（OpenAI-compatible API）
```bash
cd ~/Documents/llama/llama5050gpu.cpp/build

nohup ./bin/llama-server \
  -m ../models/Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf \
  --n-gpu-layers 50 \
  -c 4096 \
  --port 5001 \
  --host 0.0.0.0 \
  --jinja > llama-server.log 2>&1 &
```

### 6. 安裝並啟動 SillyTavern（網頁介面）
```bash
cd ~/Documents/llama

# clone 或下載最新版
git clone https://github.com/SillyTavern/SillyTavern.git

cd SillyTavern

# 安裝 Node.js（使用 NVM，避免系統 glibc 問題）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 16
nvm use 16
nvm alias default 16

# 安裝依賴（因 v16 需要 polyfill）
rm -rf node_modules
npm install --legacy-peer-deps

# 在 server.js 最上方加 polyfill（解決 structuredClone 錯誤）
# 編輯 server.js，加入：
if (typeof structuredClone === 'undefined') {
  globalThis.structuredClone = (obj) => JSON.parse(JSON.stringify(obj));
}

# 啟動（背景執行 + log）
nohup node server.js > sillytavern.log 2>&1 &

# 查看 log
tail -f sillytavern.log
```

**SillyTavern 設定（config.yaml）**  
```yaml
listen: true
port: 8000
whitelistMode: true
whitelist:
  - 127.0.0.1
  - ::1
  - 192.168.0.0/16    # 家用網段
```

### 7. 連線方式
- 本機：http://localhost:8000/
- 區域網路：http://你的nano-ip:8000/ （用 `hostname -I` 查 IP）
- API 設定（SillyTavern 右上角齒輪 → API）：
  - Type: OpenAI
  - Base URL: http://127.0.0.1:5001/v1
  - Model: qwen-coder-3b（隨便填）

### 8. 注意事項與最佳化
- **記憶體管理**：關桌面釋放 RAM  
  `sudo systemctl stop gdm` （用完再 `start gdm`）
- **模型選擇**：Nano 4GB 極限 ≈ 3B Q4_K_M，7B 以上會 OOM
- **即時資訊（如天氣）**：本地模型無法連網，需手動提供或用 SillyTavern Extensions + Web Search API
- **常見錯誤**：
  - structuredClone not defined → 加 polyfill
  - GLIBC_2.28 not found → 不要用 Node v18+，堅持 v16 + polyfill
  - 連線 Forbidden → 檢查 config.yaml whitelist

**完成日期**：2026 年 1 月 21 日  
**作者**：威廷

