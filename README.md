# US Premarket Brief

每個美股交易日 (週一至週五) 台北時間 20:30 自動產出一份繁體中文「美股盤前情報」報告，發佈到個人 GitHub Pages。

Live brief: **https://seanwangys.github.io/us-premarket-brief/**

---

## 專案目的

每日累積美股盤前情報、新聞解讀、社群情緒分析的習慣，建立金融領域知識基礎。覆蓋固定 watchlist：

- **美股**：`BTC-USD`, `NVDA`, `COPX`, `TSM`, `TSLA`, `PLTR`, `AIQ`, `QLD`, `QQQ`, `VOO`
- **台股 ETF 衍生分析**：`0050`, `00631L` (依 TSM + 美股科技基調推導)

報告涵蓋：個股新聞 / 強訊號股 digest / 散戶情緒 / 宏觀經濟 / 政治地緣，產出格式為 markdown + HTML 雙版本。

---

## 架構總覽

```
┌──────────────────────────────────────────────────────────────────┐
│ 本機 (macOS)                                                     │
│                                                                  │
│  launchd LaunchAgent  ── MTWRF 20:30 Asia/Taipei                 │
│       │                                                          │
│       ▼                                                          │
│  scripts/run-brief.sh                                            │
│       ├─ 切到 report-data branch、reset 為 origin/main            │
│       ├─ 注入 $DATE 後呼叫 `claude -p` (headless)                  │
│       │     └─ 用 moomoo skills + WebSearch 抓資料                 │
│       │     └─ 寫 data/<DATE>.md + docs/index.html + archive       │
│       ├─ git commit + force-push report-data                       │
│       └─ 成功 / 失敗皆發 macOS notification + Slack webhook         │
└──────────────────────────────────────────────────────────────────┘
                              │ push report-data
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│ GitHub                                                            │
│                                                                   │
│  .github/workflows/merge-to-main.yml                              │
│       │ trigger: push to report-data                              │
│       ▼                                                           │
│  Action: ff-only merge report-data → main → push                  │
│       │                                                           │
│       ▼                                                           │
│  GitHub Pages (source: main/docs/)                                │
│       https://seanwangys.github.io/us-premarket-brief/            │
└──────────────────────────────────────────────────────────────────┘
```

**兩個 branch 的設計動機**：本機只 push `report-data`，main 由 GitHub Actions 自動 ff-merge。這樣本機腳本永遠不直接動 main，符合「Claude/local 不直接 push production branch」的安全規則。

---

## 使用技術

| 技術 | 用途 |
|---|---|
| **launchd** (macOS native) | 系統級排程，每週一至週五 20:30 觸發 |
| **Claude CLI** (`claude -p`) | Headless 模式跑 routine prompt；用 `--allowedTools` 限定 Skill / WebSearch / Write / Edit / Read / Bash |
| **moomoo skills** (3 個 search-only) | `moomoo-news-search`、`moomoo-stock-digest`、`moomoo-comment-sentiment`；純查詢、無下單、無 OpenD 依賴 |
| **WebSearch** (Claude built-in) | 抓宏觀經濟與政治/地緣新聞 (Reuters / Bloomberg / CNBC / WSJ 優先) |
| **GitHub Actions** | `merge-to-main.yml` 自動 ff-only 合併 report-data → main |
| **GitHub Pages** | 從 `main/docs/` serve 靜態 HTML |
| **Slack Incoming Webhook** | 成功 / 失敗通知 (本機讀 `~/.config/us-premarket-brief/slack_webhook`) |
| **Shell + curl** | `run-brief.sh` 處理 git ops、log、通知 |

---

## 本機環境需求

- macOS (測試於 Darwin 24.3.0)
- 可登入的 Claude 帳號 (Claude Code 訂閱)
- Git + GitHub SSH key 已設定 (推 `report-data` branch 用)
- Slack workspace + 一條 Incoming Webhook URL
- `curl`, `openssl`, `date` (macOS 內建)

---

## 移植到新 Mac 完整流程

> 假設新 Mac 的使用者名稱為 `<NEW_USER>`，預期 repo 放在 `~/Documents/Sean/project/us-premarket-brief` (與舊 Mac 同；若不同要在多處改路徑，下面會註明)。

### Step 1 — 安裝 Claude CLI 並登入

```bash
# 1. 裝 Claude CLI (官方 install script)
curl -fsSL https://claude.ai/install.sh | bash

# 2. 確認 claude 在 PATH (預設裝到 ~/.local/bin)
which claude
# 應該回 /Users/<NEW_USER>/.local/bin/claude

# 3. 登入 (互動式，會打開瀏覽器)
claude
# 進到 interactive session 後輸入 /login，跟著 OAuth 流程，登出後 exit
```

### Step 2 — 安裝 3 個 moomoo skills

```bash
# Skills 放在 ~/.claude/skills/ 下，每個 skill 一個資料夾
mkdir -p ~/.claude/skills

# 從官方來源下載 (或從舊 Mac scp 過來)
# 官方安裝指引：https://www.moomoo.com/skills/moomoo-install.md
# 三個 skill：
#   moomoo-news-search
#   moomoo-stock-digest
#   moomoo-comment-sentiment

# 驗證
ls ~/.claude/skills/
# 應該看到三個資料夾，每個內含 SKILL.md
```

**Skills 的安全性**：純 markdown 指令、只連 `ai-news-search.moomoo.com`、無認證/Cookie、用 `--data-urlencode` 防注入。

### Step 3 — clone repo

```bash
# 假設 GitHub SSH key 已設好
mkdir -p ~/Documents/Sean/project
cd ~/Documents/Sean/project
git clone git@github.com:SeanWangYS/us-premarket-brief.git
cd us-premarket-brief
```

### Step 4 — 確認 `routine-prompt.md` 已存在

`routine-prompt.md` 是給 Claude 讀的 routine 指令；目前**已 track 在 git 內**，所以 Step 3 的 `git clone` 應該已經把它帶下來：

```bash
ls routine-prompt.md && wc -l routine-prompt.md
# 應該看到該檔案，~230 行左右
```

若您本機要對 prompt 做實驗性修改、不想 commit 上去，常用做法是 `git stash` 暫存自己改動，再 `git stash pop` 取回。**不要**重新加進 `.gitignore`，會被 `scripts/run-brief.sh` 的 sanity check 與後續同步搞混。

### Step 5 — 建立 Slack webhook URL 檔

```bash
mkdir -p ~/.config/us-premarket-brief
# 把您的 webhook URL 寫進去 (從舊 Mac 拷貝或從 Slack admin 取得新的)
echo 'https://hooks.slack.com/services/...' > ~/.config/us-premarket-brief/slack_webhook
chmod 600 ~/.config/us-premarket-brief/slack_webhook

# 測試
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"webhook test from new mac"}' \
  "$(cat ~/.config/us-premarket-brief/slack_webhook)"
# Slack channel 應該收到訊息
```

**若還沒有 webhook**：
1. 開 https://api.slack.com/apps → Create New App → From scratch → name `Premarket Brief`
2. Incoming Webhooks → On → Add New Webhook to Workspace → 選 channel
3. 複製產生的 URL

### Step 6 — 改 script + plist 內的 hardcoded 路徑 (若 username 與舊 Mac 不同)

`scripts/run-brief.sh` 內：
```bash
REPO="$HOME/Documents/Sean/project/us-premarket-brief"
```
用 `$HOME` 已經 portable；除非您要把 repo 放在不同位置，否則**不用改**。

`Library/LaunchAgents/com.seanwang.us-premarket-brief.plist` 內 hardcode 絕對路徑：
```xml
<string>/Users/sean.wang/Documents/Sean/project/us-premarket-brief/scripts/run-brief.sh</string>
...
<string>/Users/sean.wang/.local/bin:/opt/homebrew/bin:...</string>
<string>/Users/sean.wang/Library/Logs/us-premarket-brief.launchd.log</string>
```

把所有 `/Users/sean.wang/` 換成 `/Users/<NEW_USER>/` (launchd plist 不接受 `$HOME` 變數)。

### Step 7 — 安裝 launchd plist

```bash
# 從 repo 拷一份過去 (注意 repo 內沒有版本控制這個 plist；要從舊 Mac 帶過來)
cp /path/to/plist ~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist

# 驗證 plist 語法
plutil -lint ~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist
# 應該回 OK

# 暫不 load，先手動測試
```

> **TODO 改進**：未來可考慮把 plist 模板放進 repo (例如 `launchd/com.seanwang.us-premarket-brief.plist.template`)，搭配一個 `scripts/install-plist.sh` 自動帶入 `$HOME` / `$USER`。

### Step 8 — 手動跑一次驗證

```bash
bash ~/Documents/Sean/project/us-premarket-brief/scripts/run-brief.sh
```

預期耗時：8–10 分鐘 (claude headless 全程 buffer，不會 stream)。

成功的話會：
1. macOS 通知「<DATE> brief published」
2. Slack channel 收到「✅ 美股盤前情報已更新 — <DATE> + URL」
3. `~/Library/Logs/us-premarket-brief.log` 結尾出現 `=== run-brief.sh done OK ===`
4. https://seanwangys.github.io/us-premarket-brief/ 在 1–3 分鐘內更新

失敗排查：先看 log，再看 GitHub Actions tab。

### Step 9 — 啟用 launchd 排程

```bash
launchctl load ~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist
launchctl list | grep premarket
# 應該看到一行 com.seanwang.us-premarket-brief
```

下一個 MTWRF 20:30 即會自動觸發。

### Step 10 — GitHub repo 設定 (一次性，不用每台 Mac 重做；若 fork 新 repo 才要)

1. **Settings → Actions → General → Workflow permissions**：選 `Read and write permissions` (讓 ff-merge workflow 能 push main)
2. **Settings → Pages → Source**：選 `Deploy from a branch` + `main` + `/docs`
3. **建立 `report-data` branch**：從 main 開分支 (本機 push 第一次時也會自動建立)

---

## 維運速查

| 動作 | 指令 |
|---|---|
| 啟用排程 | `launchctl load ~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist` |
| 停用排程 (保留檔案) | `launchctl unload ~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist` |
| 確認排程已載入 | `launchctl list \| grep premarket` |
| 手動觸發 | `bash ~/Documents/Sean/project/us-premarket-brief/scripts/run-brief.sh` |
| 看執行 log | `tail -100 ~/Library/Logs/us-premarket-brief.log` |
| 看 launchd 自身 log | `tail -50 ~/Library/Logs/us-premarket-brief.launchd.log` |
| 改 prompt | 編 `~/Documents/Sean/project/us-premarket-brief/routine-prompt.md`；commit + push 到 main 後其他 Mac `git pull` 即同步 |
| 改觸發時間 | 編 plist 的 `StartCalendarInterval` 後 `launchctl unload && launchctl load` |
| Slack webhook 換新 | 重寫 `~/.config/us-premarket-brief/slack_webhook` (mode 600) |

---

## 故障排除 (常見問題)

### 1. claude -p 看起來「卡住」沒 output

正常現象。`claude -p` 全程 buffer，要跑完才會把整段 dump 出來。**不要 kill**，預估 8–10 分鐘。看 `~/Library/Logs/us-premarket-brief.log` 確認最後一行是不是 `starting claude -p ...`。

### 2. 報告底部「Skills loaded」三個全部 ❌

權限沒對。檢查 `scripts/run-brief.sh` 內有沒有：
```bash
--allowedTools "Skill WebSearch Write Edit Read Bash"
```

只用 `--permission-mode acceptEdits` **不夠**，Skill / WebSearch 會被 silent deny。

### 3. 散戶情緒 (`moomoo-comment-sentiment`) 報「當前無社群數據」

不是 bug。moomoo `/stock_feed` 端點對美股 watchlist 多檔回傳空 data 是上游問題；routine 已 fallback 處理。

### 4. GitHub Actions ff-merge 失敗

理論上不該發生 (因為 `run-brief.sh` 每次都 `git reset --hard origin/main` 保證 report-data 永遠領先 main 至少 1 commit)。若發生：到 Actions tab 看錯誤 → 通常是 `report-data` 與 `main` 歷史分叉了 → 解法是把 `report-data` 砍掉重建。

### 5. launchd 觸發時找不到 `claude`

plist 內 `EnvironmentVariables.PATH` 沒包含 `~/.local/bin`。檢查並補上 (用絕對路徑：`/Users/<NEW_USER>/.local/bin`)。

### 6. 排程觸發但 laptop 睡眠中

launchd `StartCalendarInterval` 預設行為：laptop 醒來後立刻補跑。如果 20:30 在睡眠中、22:30 才醒 → 22:30 才會跑那一次，**並不會跑兩次**。如果想保證準時，要用 `pmset schedule wake` 預先喚醒。

### 7. 報告日期跨夜對不上

`run-brief.sh` 已注入 `$DATE` 到 prompt header，Claude 應該用 shell 的日期。若 prompt 被改、移除了「請使用此日期，不要自行計算」段，可能會跨夜不同步。

---

## 檔案地圖

### 在 repo 內 (git 追蹤)

| 路徑 | 用途 |
|---|---|
| `routine-prompt.md` | 給 Claude 讀的 routine 指令 |
| `scripts/run-brief.sh` | launchd 入口；shell wrapper 處理 git ops + 通知 |
| `.github/workflows/merge-to-main.yml` | GH Actions ff-merge report-data → main |
| `data/<YYYY-MM-DD>.md` | 每日 markdown 原稿 (自動產生) |
| `docs/index.html` | 最新報告 (每日覆蓋) |
| `docs/archive/<YYYY-MM-DD>.html` | 每日存檔 |
| `README.md` | 本文件 |

### 系統層 (不在 repo 內)

| 路徑 | 用途 |
|---|---|
| `~/Library/LaunchAgents/com.seanwang.us-premarket-brief.plist` | launchd 排程設定 |
| `~/Library/Logs/us-premarket-brief.log` | run-brief.sh + claude 整合 log |
| `~/Library/Logs/us-premarket-brief.launchd.log` | launchd 自身 stdout/stderr |
| `~/.config/us-premarket-brief/slack_webhook` | Slack Incoming Webhook URL (mode 600) |
| `~/.claude/skills/moomoo-news-search/` | moomoo 個股新聞 skill |
| `~/.claude/skills/moomoo-stock-digest/` | moomoo 個股 digest skill |
| `~/.claude/skills/moomoo-comment-sentiment/` | moomoo 散戶情緒 skill |

---

## 安全 / 合規備註

- **Skills 範圍**：只用 search-only skills，未安裝 OpenD / 下單 / anomaly 類 skill
- **本機 push 限制**：`run-brief.sh` 內的 `git push -f` 只動 `report-data` branch，不直接動 `main`
- **GH Actions 寫 main**：由使用者在 repo Settings 明確授權設定的 workflow 完成，不是由 Claude 即時動手
- **Slack URL 是 credential**：存放在 `~/.config/us-premarket-brief/slack_webhook`，mode 600，**不**進 git
- **報告免責聲明**：每份 brief 底部有「本報告僅整理公開資訊，不構成任何投資建議」
