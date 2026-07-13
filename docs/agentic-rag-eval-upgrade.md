# 美股盤前日報 → Agentic RAG + Eval 升級設計

> 建立日期：2026-07-11。作者：Sean（＋AI 協作）。
> 本文件是這次升級的**權威設計**：功能規格、定案技術棧、成本模型、學習路徑、里程碑。
> 背景動機（求職策略層）見求職 workspace `hunting/AI時代職涯研究/報告五`；本文件只談這個專案怎麼做。

---

## 1. 目的

把現有「每日美股盤前情報」從 **Claude CLI headless 一支 prompt** 升級成 **agentic RAG pipeline + 可量測的 eval 品質閘門**。雙目標：

1. **學習**：用業界實際常用的現成套件（不從底層造輪子），把四組市場最搶手的 LLM 應用技能做進一個真實服務——agentic 編排、生產級 RAG、eval/可觀測性、guardrails。
2. **產品**：維持一個**高可用、每天在跑、有實際價值**的服務；升級後簡報更有根據（每句話可追來源）、有延續性（延續/反轉過去判斷）、品質可被量測。

## 2. 現況與落差

**現況**：`launchd`（MTWRF 20:30）→ `scripts/run-brief.sh` → `claude -p` 讀 `routine-prompt.md`（6 步）→ moomoo skills + WebSearch 抓資料 → 寫 `data/<DATE>.md` + `docs/index.html` → push `report-data` → GitHub Action ff-merge 到 `main` → GitHub Pages。已穩定運行 30+ 天。

**四個落差**：

| 落差 | 現況 | 升級後 |
|---|---|---|
| 無 RAG／無記憶 | 每天從零搜尋，30+ 天歷史簡報語料未被使用 | 歷史簡報＋當日新聞原文進向量庫，做 grounding 與延續性檢索 |
| 無結構化編排 | 一支大 prompt 線性跑 6 步 | LangGraph 狀態圖：plan→retrieve→draft→reflect→render |
| 無 eval | 只有「檔案存在」self-check | RAGAS faithfulness/groundedness 打分＋黃金資料集＋CI gate |
| 無引用查核 | 有附連結，但沒驗證「這句話真的來自這個來源」 | 結構化輸出＋citation 對齊驗證（guardrail） |

## 3. 架構決策：漸進式 Strangler（不弄壞正在跑的服務）

- **不動**現有 CLI 服務——它繼續每天發報，保住「高可用」。
- **另建**一套 Python agentic-RAG + eval pipeline，在旁邊長大（獨立目錄，見 §9）。
- **用 eval gate 決定切換**：新 pipeline 連續 N 天品質分數 ≥ 舊的基準，才切為正式服務；舊 CLI 保留為 fallback。

> 為什麼：同時滿足（a）學到真正的框架、（b）服務不中斷、（c）「用 eval 分數決定能不能上線」本身就是最強的求職敘事（把不可靠系統變成生產級可信任服務）。

## 4. 定案技術棧（全部市場實際常用、可攜、不綁單一廠商）

| 層 | 選型 | 理由 |
|---|---|---|
| Agent 編排 | **LangGraph** | 生產環境 #1 agent 框架；狀態圖、durable、human-in-the-loop |
| 向量庫 | **Qdrant**（本機 Docker）＋ hybrid（BM25 + dense） | 生產級開源向量庫、效能標竿、client 乾淨；hybrid 是 2026 生產標配。**M2 時若想吃 Postgres 老本，可平替 pgvector** |
| Embedding | **本機模型**（`nomic-embed-text` via Ollama 或 sentence-transformers `bge`） | $0、離線、夠用 |
| Dev 評測 | **RAGAS** | 2026 最多人用的開源 RAG 評測庫；RAG 專用指標最深 |
| CI gate 評測 | **DeepEval** | pytest 形狀，分數掉就 fail build |
| 可觀測性 | **Langfuse**（已定案 2026-07-12：自架 Docker Compose）＋ OpenTelemetry | 開源採用領導者、框架無關、學到可攜的 OTel |
| LLM | **Claude API**（生成用 Sonnet；eval judge 用 Sonnet，偶爾 Opus 驗證） | 已在生態；成本見 §8 |
| 結構化輸出/guardrails | **Pydantic** | 型別安全的結構化輸出＋citation 驗證 |
| 語言/執行 | Python 3.11+、`uv` 或 `venv` | — |

**曾評估但不選**：Chroma（僅雛形用）、純本機自架 LLM（省的錢很少、難度不成比例，見 §8）。

## 5. 功能規格（五個邊界清楚、可獨立測試的元件）

1. **`ingest/` 資料擷取層**：沿用現有來源（moomoo/新聞/WebSearch 等值），輸出「當日原始新聞文件」= 全文 + URL + 時間戳 + ticker 標記。與編排解耦，只負責交出原文。
2. **`retrieval/` 知識庫／檢索層**：Qdrant 存兩種語料——(a) 歷史簡報、(b) 當日新聞原文。提供兩種檢索：**grounding 檢索**（寫某檔時撈其來源原文）、**延續性檢索**（撈過去對該檔的說法，讓簡報能講「延續上週趨勢／反轉週二判斷」）。
3. **`graph/` 編排層（LangGraph）**：`plan`（今天研究哪些 ticker/主題）→ `retrieve` → `draft`（逐檔結構化輸出：事實／方向／信心／citation）→ `reflect`（自查有無無根據宣稱）→ `render`（markdown + HTML）。
4. **`eval/` 評測層（RAGAS + DeepEval + Langfuse）**：黃金資料集＝歷史簡報＋標註；指標＝faithfulness、context precision/recall、answer relevancy；每次跑留 Langfuse trace 可回放；一頁「答錯案例」分析。
5. **`gate/` 守門與發布**：faithfulness < 門檻就擋下、不發布；沿用現有 `report-data`→`main` 兩分支不變量（見 §9），只多一道 eval gate。

## 6. 學習路徑（依「先能測量、再改系統」排序）

| 順序 | 學什麼（現成套件） | 目標技能 | 對應里程碑 |
|---|---|---|---|
| 1 | RAGAS + Langfuse 基礎（eval 概念、dataset、LLM-as-judge、trace） | eval／可觀測性（★最高訊號） | M0–M1 |
| 2 | embeddings + Qdrant、chunking、hybrid、檢索評測 | 生產級 RAG | M2 |
| 3 | LangGraph（node/edge/state、條件路由、reflect 迴圈） | agentic 編排 | M3 |
| 4 | Pydantic 結構化輸出 + guardrails；trace 看成本/延遲 | guardrails／治理 | M4 |
| 5 | OpenTelemetry 概念（Langfuse trace 導出） | 可觀測性延伸 | 貫穿 |

## 7. 里程碑（每個都能單獨收尾、都不弄壞現有服務）

> 執行方式：**一個里程碑 ≈ 一個 OpenSpec change**（explore→propose→apply→archive）。第一個 change＝M0+M1。

- **M0 地基**（~3–5 天）：Python 專案骨架、接上 Langfuse tracing、把 30+ 天 `data/*.md` 匯入成 baseline 資料集。**DoD**：能對現有簡報跑一次 trace。**練到**：可觀測性起步。
- **M1 Eval-first**（~1 週，★最高價值先做）：**在還沒改 pipeline 前，先能「評分現有報告」**——建 RAGAS harness + 黃金資料集 + 答錯案例頁。**DoD**：產出一份「現有服務的品質基準分數」，之後每一步都可對比。**練到**：eval。
- **M2 RAG 檢索層**（~1 週）：灌 Qdrant、grounding + 延續性檢索、hybrid；先當「輔助資料」餵給現有 prompt 驗證有沒有變好。**DoD**：context precision/recall 數字。**練到**：生產級 RAG。
- **M3 LangGraph 編排**（~1.5 週）：6 步改寫成狀態圖 + 結構化輸出 + citation。**DoD**：新 pipeline 能端到端產出一份簡報。**練到**：agentic 編排。
- **M4 Guardrails + CI gate**（~1 週）：faithfulness 沒到門檻擋下；接進發布流程（gate）。**DoD**：帶品質門檻的新 pipeline。**練到**：guardrails。
- **M5 Cutover**（~3–5 天）：新 pipeline 連續 N 天分數 ≥ 舊基準才切正式、舊 CLI 留 fallback；寫一篇架構 ADR。**DoD**：旗艦作品 + 完整面試敘事。**練到**：整套閉環。

**關鍵設計選擇**：eval 先做（M1 在 M2/M3 之前）——它是最高求職訊號、也讓後面每步都有分數可比，對應招募端說的「跑真實 query、把答錯的挑出來分析」。

## 8. 成本模型（Claude API）

一天一次的批次工作（週一到五、~21 次/月），成本很小；真正花費是開發期一次性的 eval 迭代。

- **生產（穩定運行）**：每次生成約 65k 輸入 + 8k 輸出。**Haiku≈$2／Sonnet≈$4–7／Opus≈$11 每月**。
- **開發／eval 迭代（前期集中、一次性）**：務實紀律下（15 題黃金集、judge 用 Sonnet、只評分不重生成、~40 輪）累計約 **$40–70**；放縱跑可衝到幾百。
- **成本歸零/減半的手段**：embedding 本機（整類歸零）、judge 用便宜模型、快取生成不重跑、黃金集小、eval 走 **Batch API（5 折）**、RAGAS 迭代只跑部分指標。

> 註：RAG 的「檢索」步驟（embedding + 向量搜尋）不經過 Claude API、不花錢；花錢的是把檢索內容餵給生成 LLM。RAG 是 token 節流閥，不是漏斗。定價：Haiku $1/$5、Sonnet 5 $3/$15（優惠 $2/$10 至 2026-08-31）、Opus 4.8 $5/$25（每百萬 token）。

## 9. 不變量與護欄（違反前停下找 owner）

1. **絕不弄壞正在跑的 CLI 服務**：新 pipeline 是獨立 Python 專案，放獨立目錄（建議 `agentic/`），在 M5 cutover 前**不碰** `run-brief.sh`／`routine-prompt.md`／發布流程。
2. **兩分支發布不變量**（見 `CLAUDE.md`）：本機只 push `report-data`，`report-data` 永遠是 `main + 1 commit`，Action 做 ff-only merge。新 pipeline cutover 時沿用此模型，不直接 push `main`。
3. **自動產生檔不手改**：`data/<DATE>.md`、`docs/index.html`、`docs/archive/*.html` 由 routine 覆寫。
4. **祕密不進 repo、不進 prompt**：API key 走環境變數；Slack webhook 沿用 `~/.config/us-premarket-brief/`。
5. **headless 權限雷區**：若動到 `claude -p` 呼叫，保留 `--allowedTools`，勿改 `--permission-mode acceptEdits`（會靜默停用 Skill/WebSearch）。

## 10. 現況資產（可複用）

- 30+ 天歷史簡報 `data/2026-05-18.md` … 起（直接當黃金資料集語料）。
- 固定 watchlist：`BTC-USD`, `NVDA`, `TSM`, `TSLA`, `PLTR`, `QQQ`, `VOO` + 台股 ETF 衍生（`0050`, `00631L`）。
- 既有簡報結構（TL;DR／個股動態／情緒指標／AI 產業／宏觀／政治地緣）＝新 pipeline 的輸出 schema 起點。

---

## 執行狀態

- [x] 設計定案（本文件）
- [ ] M0+M1（OpenSpec change：`add-eval-baseline`）
- [ ] M2 / M3 / M4 / M5（各一個 OpenSpec change）
