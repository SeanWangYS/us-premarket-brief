# 美股盤前情報整理員 — Routine Prompt（headless 版）

> 由 `scripts/run-brief.sh` 透過 `claude -p` 觸發。
> **報告日期 `{DATE}` 與生成時間 `{RUN_TIME}`**：兩者皆由 shell 在本 prompt 最上方「Runtime context」段注入，**請逐字使用，不要自行用 `date` 指令計算**（`{DATE}` 跨夜不一致、`{RUN_TIME}` 自行猜測會誤導讀者）。
> 產出語言：**繁體中文**。不提供投資建議；只整理事實 + 影響方向 + 來源連結。
>
> **責任邊界**：本 prompt 只負責「抓資料 + 寫檔」。Git commit / push 由 `run-brief.sh` 處理，**不要**自己跑 git 指令。

---

## 觀察清單（鎖定，請勿擅自增減）

**US tickers**（呼叫 moomoo skills）：
`BTC-USD`（keyword 用 `Bitcoin`）, `NVDA`, `COPX`, `TSM`, `TSLA`, `PLTR`, `AIQ`, `QLD`, `QQQ`, `VOO`

**衍生連動標的**（不另取資料、不取台灣本地新聞）：
- `0050`、`00631L`：以 TSM 新聞 + 美股科技整體基調做衍生分析
- 備註：`00631L` 為 `0050` 的 2x 槓桿；`0050` 成份近 6 成為 TSM + 大型科技權值股

---

## 工作流程（共 6 步）

### 步驟 1 — 個股新聞（呼叫 `moomoo-news-search` skill）

對每個 US ticker，呼叫 `moomoo-news-search` skill：
- `symbol`：對 `BTC-USD` 用 `Bitcoin`、對 `AIQ` 用 `Global X Artificial Intelligence ETF`（AIQ ticker 在 keyword search 會撈到同代碼的英國微型股，需用全名），其餘用 ticker 本身
- `size`：`8`
- `news_type`：`1`（News）
- `lang`：`en`（資料源覆蓋廣；最後合成時翻成繁體中文）
- `sort_type`：`2`（依時間排序）

若 skill 回傳「No data available at the moment」或內部失敗，**記下失敗的 ticker 名，繼續下一檔**，不要整個中斷。

每檔萃取：
- **頭條 1–2 條**（事實一句話，避免標題殺人）
- **影響方向**：利多 / 利空 / 中性
- **信心度**：高 / 中 / 低（同一事件多家覆蓋 = 高；邊緣訊號 = 低）
- **主要來源連結**（保留 skill 回傳的 URL 欄位）

### 步驟 1.5 — 強訊號個股加深 digest（呼叫 `moomoo-stock-digest` skill）

從步驟 1 的結果，挑出**訊號最強的 1–3 檔**（重大財報、購併、制裁、產品發表、巨幅波動催化）呼叫 `moomoo-stock-digest` skill 取深度解讀：
- `symbol`：該 ticker
- `size`：`10`
- `lang`：`en`

把 digest 給的 `bullish` / `bearish` / `neutral` 判斷 + 關鍵信號融入步驟 1 該檔的解讀。若沒有特別強的訊號，跳過本步驟。

### 步驟 2 — 情緒指標（WebSearch 公開來源）

抓兩個指標，反映當日整體市場情緒（不再做 per-ticker 散戶比例）：

**A. AAII Sentiment Survey（週頻 Bull / Neutral / Bear %）**
- 用 `WebSearch` 查：`"AAII Sentiment Survey latest week bullish bearish"`
- 從第一條媒體報導（Seeking Alpha / MarketWatch / MSN / Yardeni / aaii.com 任一可信來源）取：
  - **as-of 週末日期**（AAII 每週四下午公布上一個調查週期結果）
  - **Bullish %**、**Neutral %**、**Bearish %**
  - **Bull-Bear spread**（若有）
- AAII 是週頻指標。週四前的 brief 會看到同一個數字；**直接寫，明確標 as-of 日期**

**B. VIX 恐慌指數（日頻）**
- 用 `WebSearch` 查：`"VIX index today close CBOE"`
- 從第一條報導取：**當前值（或最新收盤）**、**與前一日比較的點數 / 百分比**、（若有）**日內區間**
- 解讀提示（一句話寫進報告）：< 15 = 平靜；15–20 = 中性；20–25 = 警戒；> 25 = 避險升溫

若兩個來源**都**抓不到：該段註記「**情緒指標：當日無公開數據**」，不要捏造。
單一來源失敗：把成功那個寫出，失敗那個註記「（{來源}：當日無公開數據）」。

### 步驟 3 — 宏觀經濟（WebSearch，過去 24 小時）

優先來源：`reuters.com`、`bloomberg.com`、`cnbc.com`、`wsj.com`

依序查詢：
- `"FOMC OR Fed rate decision OR Fed speech today"`
- `"US CPI OR PCE OR jobs report OR retail sales"`
- `"10-year Treasury yield OR DXY dollar index"`

每類取**最多 1–2 條最重要的**，一句摘要 + 連結。沒有就跳過。

### 步驟 4 — 政治 / 地緣（WebSearch）

依序查詢：
- `"White House executive order tariff trade"`
- `"US Congress bill markets"`
- `"China US tech sanctions chips"`
- `"geopolitics Middle East OR Taiwan OR Russia oil"`

每類取**最多 1 條**，一句摘要 + 連結。沒有就跳過。

### 步驟 5 — 寫 `data/{DATE}.md`（原始 markdown）

用 `Write` tool 寫到 `./data/{DATE}.md`，**固定結構**如下，每節 3–5 條，控制在 1 頁 A4 可讀完：

```markdown
# 美股盤前情報 — {DATE}

> 生成時間：{RUN_TIME} Asia/Taipei
> 本報告由自動化 routine 產生，僅整理公開資訊，**不構成投資建議**。

## TL;DR

- {三條最關鍵的事，最先讀的人也能拿到要點}

## 個股動態

依清單順序：`BTC-USD`, `NVDA`, `COPX`, `TSM`, `TSLA`, `PLTR`, `AIQ`, `QLD`, `QQQ`, `VOO`

- **NVDA**：{頭條一句} | {方向：利多/利空/中性} | {信心：高/中/低} | [來源]({url})
- **TSM**：…
- …

### 台股連動 ETF（衍生分析、未取台灣本地新聞）

- **0050**：依 TSM 與美股科技整體推導 → {方向}
- **00631L**：方向同 `0050` 但 2x 放大；高波動日注意 reset 損耗

## 情緒指標

- **AAII（截至 {asof_date}）**：Bull {x}% / Neutral {y}% / Bear {z}%　·　Bull-Bear spread {±s}%
- **VIX**：{value}（前日 {±point}, {±pct}%）—{一句解讀}

（若兩個來源都失敗則本節改為：「當日無公開數據」；單一來源失敗則該行改為「{來源}：當日無公開數據」）

## 宏觀經濟（過去 24 小時）

- {一句}（[連結]({url}))
- …

## 政治 / 地緣

- {一句}（[連結]({url}))
- …

## 今日失敗項目（debug 用，正常為空）

- {例：moomoo-news-search 對 BTC-USD 回傳 No data}

## Instrument（自我檢查；穩定後可移除此段）

- **Skills loaded**：moomoo-news-search=✅/❌, moomoo-stock-digest=✅/❌
  - 載入判斷：若該 skill 在本次任務中可以被呼叫且回傳有效結構（即使 data 為空，只要 code=0 或回傳 disclaimer template，皆算 ✅），否則 ❌
- **WebSearch**：✅/❌
- **情緒指標來源**：AAII=✅/❌, VIX=✅/❌

## 免責聲明

本報告僅整理公開資訊，**不構成任何投資建議**，亦不保證資料完整正確。請自行判斷風險。
```

### 步驟 6 — 寫 `docs/index.html` + `docs/archive/{DATE}.html`

用 `Write` tool **逐字寫出兩份 HTML 檔案**（內容相同），不要產生 Python 中介腳本。

HTML template（請把 `{DATE}`、`{RUN_TIME}`、`{BODY_HTML}` 替換為實際值，**其餘所有 CSS / 結構不要動**）：

```html
<!DOCTYPE html>
<html lang="zh-Hant">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>美股盤前情報 — {DATE}</title>
  <style>
    body{background:#0d1117;color:#c9d1d9;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;font-size:18px;line-height:1.7;max-width:860px;margin:40px auto;padding:0 24px 60px}
    h1{color:#58a6ff;border-bottom:1px solid #30363d;padding-bottom:10px}
    h2{color:#79c0ff;margin-top:32px}
    h3{color:#d2a8ff}
    a{color:#58a6ff;text-decoration:none}
    a:hover{text-decoration:underline}
    table{border-collapse:collapse;width:100%;margin:16px 0}
    th,td{border:1px solid #30363d;padding:8px 12px;text-align:left}
    th{background:#161b22;color:#79c0ff}
    tr:nth-child(even){background:#161b22}
    hr{border:none;border-top:1px solid #30363d;margin:24px 0}
    blockquote{border-left:3px solid #30363d;color:#8b949e;margin:16px 0;padding:4px 16px}
    code{background:#161b22;padding:2px 6px;border-radius:4px}
    .meta{font-size:14px;color:#8b949e;margin-top:48px;border-top:1px solid #30363d;padding-top:12px}
  </style>
</head>
<body>
{BODY_HTML}
<div class="meta">
  產生時間：{RUN_TIME} (Asia/Taipei)　｜
  <a href="archive/{DATE}.html">本日存檔</a>　｜
  <a href="https://github.com/SeanWangYS/us-premarket-brief">GitHub</a>
</div>
</body>
</html>
```

**HTML 轉換規則**（你自己把步驟 5 的 markdown 轉成 `{BODY_HTML}`，**不要呼叫外部 markdown library 或寫 Python**）：
- `# 標題` → `<h1>標題</h1>`
- `## 標題` → `<h2>標題</h2>`
- `### 標題` → `<h3>標題</h3>`
- `> 引用` → `<blockquote>引用</blockquote>`
- `- 項目` 連續行 → `<ul><li>項目</li>…</ul>`
- `1. 項目` 連續行 → `<ol><li>項目</li>…</ol>`
- `**粗體**` → `<strong>粗體</strong>`
- `[文字](url)` → `<a href="url">文字</a>`
- 空行分段 → `<p>段落</p>`
- 確保 `<`, `>`, `&` 在非標籤位置正確 escape（最少 `&amp;` `&lt;` `&gt;`）

兩個檔案（`docs/index.html` 與 `docs/archive/{DATE}.html`）**內容完全相同**，只是路徑不同。

**注意 archive 目錄**：`docs/archive/` 已存在；若 `docs/archive/{DATE}.html` 已存在則直接覆蓋（同一天重跑算正常）。

---

## 失敗 / Fallback 規則

- 任何單一 ticker / 單一 step 失敗，**記到「今日失敗項目」段落並繼續**，不要中斷整個流程
- 若 AAII 與 VIX 兩個情緒指標來源**都**失敗：情緒指標段改為「當日無公開數據」（單一來源失敗則該行單獨註記）
- 若所有 moomoo skills 都 ❌：仍要寫出 `data/{DATE}.md` 與 HTML（用「個股新聞抓取失敗」說明，並維持其他段落），讓 shell wrapper 能正常 commit
- **絕對不要**：跑 git 指令、寫 `/tmp/*.py` 中介腳本、發出網路請求到 ai-news-search.moomoo.com 以外的服務（WebSearch 例外）

---

## 完成標準（self-check before finishing）

退出前**自我驗證**：
1. `./data/{DATE}.md` 已存在
2. `./docs/index.html` 已存在（內容是今日報告）
3. `./docs/archive/{DATE}.html` 已存在（與 index.html 內容相同）
4. 報告 markdown 涵蓋 watchlist 全部 12 個項目（10 美股 + 2 台股 ETF 衍生）
5. 「Instrument」段兩個 skill + WebSearch + AAII / VIX 狀態都有標記
6. 沒有跑過任何 `git` 指令

若 1–5 任一不滿足：**重做該步驟**直到滿足；若無論如何寫不出檔（disk full / permission），exit 非零讓 shell wrapper 抓到失敗。
