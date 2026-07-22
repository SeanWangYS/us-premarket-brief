# 美股盤前日報 → Agentic RAG 架構設計（HOW）

> 建立日期：2026-07-22。作者：Sean（＋AI 協作）。
> **狀態：討論中草稿，尚未定案。** 本文件會與 Sean 來回討論、修改後才定稿；定稿前不作為實作依據。
>
> **這份文件的定位**：它是 [`agentic-rag-eval-upgrade.md`](./agentic-rag-eval-upgrade.md)（權威文件）的**姊妹篇**。
> 兩者分工如下——避免把「幾乎不會變的策略」與「會一直迭代的設計」混在同一份而造成混亂：
>
> | 文件 | 回答 | 變動頻率 |
> |---|---|---|
> | `agentic-rag-eval-upgrade.md`（權威） | **WHY／WHAT／WHEN**：動機、選什麼技術、里程碑、成本 | 低（北極星） |
> | `architecture.md`（本文件） | **HOW**：資料契約、模組介面、資料流、待決設計登記 | 高（設計層，一直改到定案） |

---

## 0. 為什麼需要這份文件

權威文件 §4「定案技術棧」把「要用什麼技術」列清楚了（LangGraph、Qdrant、RAGAS…），但那是**技術清單**，不是**架構設計**。開始寫程式前，真正需要先講清楚的是這三件事——它們是「模組之間怎麼接」的合約，缺了它們就會邊寫邊改介面、越寫越亂：

1. **模組地圖 + 資料流**：東西從哪流到哪、每個模組吃什麼吐什麼。（§1、§2）
2. **資料契約（schema）**：模組之間傳遞的資料長什麼樣——這是「架構」與「技術清單」最大的差別。（§3）
3. **待決設計登記表**：還沒想清楚的項目，各自什麼狀態、預設提案是什麼、何時定案。（§4）

---

## 1. 系統模組地圖

比權威文件 §5 的五個元件多切出一個 **`corpus/`（進庫層）**。原因：權威文件把「怎麼把資料放進 Qdrant」和「怎麼從 Qdrant 查資料」混在 `retrieval/` 一層裡描述，但這是兩件責任完全不同的事——**寫入（corpus）** 和 **讀取（retrieval）** 分開，Sean 列的 5 個未設計項才有明確的家。

| 模組 | 一句話職責 | 輸入 | 輸出 | 依賴 | 里程碑 |
|---|---|---|---|---|---|
| **`ingest/`** | 抓來源、交出並保存當日原文 | watchlist、日期 | `RawNewsDoc[]` ＋落地 `data/raw/<date>/*.json` | moomoo HTTP API、LLM 原生 web search | R0（落地）→ M2（進庫串接） |
| **`corpus/`** | 把語料 chunk＋embed＋upsert 進 Qdrant | 歷史簡報 `data/*.md`、`data/raw/*.json` | Qdrant 內的向量點 | 本機 embedding、Qdrant | M2 |
| **`retrieval/`** | 從 Qdrant 查兩種語料 | 查詢（ticker／日期／文字） | `Chunk[]` | Qdrant | M2 |
| **`graph/`** | LangGraph 狀態圖編排五個節點 | 日期 | `Brief` ＋ markdown/HTML | retrieval、外部 LLM API | M3 |
| **`eval/`** | RAGAS/DeepEval 打分＋Langfuse trace | 簡報、黃金集 | 分數、答錯案例頁 | 外部 LLM（judge）、Langfuse | M1（先行）、貫穿 |
| **`gate/`** | 品質門檻守門＋沿用兩分支發布 | 簡報＋分數 | 發布 or 擋下 | eval | M4–M5 |

**兩種檢索**（`retrieval/` 提供，見 §3.4）：
- **grounding 檢索**：寫某檔時撈它的來源原文 → 每句話可追來源。
- **延續性檢索**：撈過去對該檔的說法 → 簡報能講「延續上週趨勢／反轉週二判斷」。

---

## 2. 資料流

```
┌─ 每日語料流（先於簡報生成，可獨立跑）────────────────────────────┐
│                                                                      │
│  ingest/  ──抓──►  RawNewsDoc[]                                       │
│    │  來源：moomoo HTTP API（Python 直呼）、LLM 原生 web search        │
│    │                                                                  │
│    ├──[R0]──►  落地 data/raw/<date>/*.json   （原文保存，可立即做）    │
│    │                                                                  │
│    └──[M2]──►  corpus/  chunk + embed + upsert  ──►  Qdrant           │
│                          ▲ Sean 列的 5 個未設計項全在這層（見 §4）     │
│                                                                      │
│  （一次性）歷史簡報 data/*.md ──[M2 backfill]──► corpus/ ──► Qdrant   │
└──────────────────────────────────────────────────────────────────────┘

┌─ 簡報生成流（graph/，LangGraph 狀態圖）──────────────────────────────┐
│                                                                        │
│  plan ──► retrieve ──────► draft ──────► reflect ──────► render        │
│   │         │               │              │               │           │
│   │    retrieval/:      逐檔結構化      查有無無根據      markdown        │
│   │    · grounding      輸出(帶        宣稱、citation    + HTML          │
│   │    · continuity     citations)     對齊驗證                         │
│   │                                                                    │
│   └──────────────────────► gate/ ──► 分數達標？──► 發布(兩分支不變量)    │
│                                    └► 未達標 ──► 擋下                    │
└────────────────────────────────────────────────────────────────────────┘
```

**關鍵脈絡**：語料流與生成流**解耦**。R0 現在就能開始存原文（語料越晚存損失越大）；corpus 進庫（M2）串在語料流上、不塞進 `run-brief.sh` 關鍵路徑；生成流（M3）在旁邊長大，M5 才 cutover。

---

## 3. 資料契約（schema）

> 以下用 Pydantic 風格 pseudocode 表達「合約」。欄位定案、型別待實作微調。這是本文件最缺、也最能消除混亂的部分。

### 3.1 `RawNewsDoc` — ingest 產出＝`data/raw/` 落地格式（R0 直接可做）

```python
class RawNewsDoc(BaseModel):
    doc_id: str                       # 確定性 ID，見 §4「冪等性」
    doc_type: Literal["news"] = "news"
    ticker: str | None                # 標的；宏觀／產業類新聞可為 None
    source: Literal["moomoo", "websearch"]
    source_url: str
    title: str
    full_text: str                    # ★ 全文——這正是現行 routine 沒存、閱後即焚的東西
    published_at: datetime            # 新聞發布時間（來源提供）
    fetched_at: datetime              # 我方抓取時間
```

落地：每篇一個檔 `data/raw/<YYYY-MM-DD>/<doc_id>.json`，內容就是這個物件序列化。
> 註：moomoo API 實際回傳欄位對應在 R0 實作時確認；此契約是我方**正規化後**的統一格式，遮蔽來源差異。

### 3.2 Qdrant point payload — corpus 寫入、retrieval 讀出

```python
class ChunkPayload(BaseModel):
    chunk_id: str                     # 確定性 ID，見 §4「冪等性」
    doc_type: Literal["brief", "news"]
    ticker: str | None
    date: date                        # 簡報日期 or 新聞發布日
    section: str | None               # brief 專用：TL;DR/個股/情緒/AI產業/宏觀/地緣；news 為 None
    source_url: str | None
    text: str                         # 這個 chunk 的內容
    ingested_at: datetime
# 向量：dense（nomic-embed-text 或 bge）＋ sparse（BM25）＝ hybrid（權威 §4）
```

`ticker`／`date`／`section`／`doc_type` 就是權威文件 §5.2 point (iv) 說的 metadata schema，這裡把它凍結成具體欄位。

### 3.3 `Brief` 輸出 schema — graph.draft 產出（個股呈現格式**暫定**）

```python
class Citation(BaseModel):
    source_url: str
    quote: str                        # 來源原文片段；reflect 與 faithfulness 靠它做對齊驗證

class StockNote(BaseModel):           # ⚠️ 呈現「格式」暫定，但欄位先鎖 citations
    ticker: str
    fact: str                         # 今日事實
    direction: str                    # 方向判斷
    confidence: str                   # 信心水準
    citations: list[Citation]         # ★ 「可信度」整條敘事的技術落點

class Brief(BaseModel):
    date: date
    generated_at: datetime
    tldr: str
    stocks: list[StockNote]           # 個股區——呈現格式待 deep-research 定案
    sentiment: dict                   # 情緒指標（AAII／VIX…）
    ai_industry: list[str]
    macro: list[str]
    geopolitics: list[str]
```

> **為什麼個股格式暫定、citations 卻先鎖**：Sean 已否決現行單行格式，個股「怎麼呈現」要另做 deep-research（另有 `docs/brief-format-research` 進行中，權威文件 §10 註）。但無論最後長怎樣，**每句個股判斷都要掛 `citations`**——這是 reflect node 驗證、RAGAS faithfulness 打分的技術前提。所以呈現格式後補，`citations` 欄位現在就鎖。

### 3.4 檢索介面 — `retrieval/` 對外簽名

```python
def grounding_retrieve(ticker: str, date: date, query: str, k: int = 8) -> list[Chunk]:
    """寫某檔時，撈它當日／近期的來源原文（doc_type='news'）。"""

def continuity_retrieve(ticker: str, lookback_days: int = 14, k: int = 5) -> list[Chunk]:
    """撈過去對該檔的既有說法（doc_type='brief'），支撐『延續／反轉』敘事。"""
```

### 3.5 `GraphState` — LangGraph 節點間傳遞的狀態（M3）

```python
class GraphState(TypedDict):
    date: date
    plan: list[TickerPlan]            # plan 節點：今天研究哪些 ticker／主題
    grounding: dict[str, list[Chunk]] # retrieve 節點：{ticker: 來源原文}
    continuity: dict[str, list[Chunk]]# retrieve 節點：{ticker: 過去說法}
    draft: Brief                      # draft 節點：結構化簡報
    reflection: ReflectReport         # reflect 節點：無根據宣稱清單
    rendered: RenderedOutput          # render 節點：markdown + HTML
```

---

## 4. 待決設計登記表

Sean 列出的 5 個未設計項，全部記錄於此。原則：**能定的現在凍結，需要實際資料才能決定的留給 M2 實驗**——不會忘、也不會過早凍結。

| # | 項目 | 狀態 | 預設提案 | 何時定案 |
|---|---|---|---|---|
| 1 | **Metadata schema** | ✅ 現在定 | §3.2 六欄位：`doc_type`／`ticker`／`date`／`section`／`source_url`／`ingested_at` | 已定 |
| 2 | **冪等性 ID** | ✅ 現在定 | `chunk_id = sha1(f"{doc_type}\|{date}\|{ticker}\|{section}\|{chunk_index}")`；`doc_id = sha1(f"{source}\|{source_url}")`。同日重跑 → 相同 ID → upsert 覆蓋，不產生重複語料 | 已定 |
| 3 | **歷史回填 backfill** | ✅ 範圍定 | 一次性腳本，讀 `data/*.md`（30+ 天）→ 按 section 切 → 進 Qdrant；M2 開工時跑一次 | 範圍已定，實作於 M2 |
| 4 | **每日增量觸發點** | ⚠️ 傾向定 | 掛在每日 routine **之後**獨立跑（R0 落地原文 → corpus 進庫），**不塞進 `run-brief.sh` 關鍵路徑**（護欄：不弄壞正在跑的服務） | M2 確認 |
| 5 | **Chunking 策略** | ❌ 別現在定 | 候選：簡報按 section 切、新聞原文按段落切；**需灌過真實資料看檢索品質才決定**（過早凍結一定錯） | M2 實驗後定 |

---

## 5. 設計決策記錄（ADR-lite）

記錄「為什麼這樣切」，避免之後重複討論同一件事。

- **D1：`corpus/` 從 `retrieval/` 拆出。** 寫入與讀取是不同責任、不同觸發時機（寫入掛語料流、讀取掛生成流）。合在一起是先前「有點混亂」的來源之一。
- **D2：`citations` 欄位先於個股呈現格式凍結。** 可信度敘事（reflect 驗證 + faithfulness 打分）依賴逐句掛來源；呈現格式怎麼變都不影響這個底層需求。
- **D3：R0 原文落地最優先、且獨立於一切決策。** 歷史簡報可回填，新聞原文閱後即焚、外部連結會失效——語料只能從開始存那天累積。與 eval 黃金集決策互不阻塞。
- **D4：確定性 ID（非隨機 UUID）。** 讓「同日重跑」天然冪等，不需額外去重邏輯。
- **D5：LLM 廠商中立。** 只有 plan／draft／reflect／eval-judge 四節點呼叫 LLM（權威 §4 廠商中立原則）；本文件所有契約與介面都與廠商無關。

---

## 6. 開放問題（尚待 Sean 內化後與 AI 討論）

這些不阻擋 R0，但在 M2/M3 開工前值得談定：

1. **個股呈現格式**：等 deep-research（`docs/brief-format-research`）結論，回頭補 §3.3 的 `StockNote` 呈現層。
2. **`plan` 節點的自主程度**：固定 watchlist 全跑，還是讓 LLM 依當日新聞熱度決定研究哪些？（影響 §3.5 `TickerPlan`）
3. **`sentiment` 欄位結構**：目前 §3.3 用 `dict` 佔位；AAII／VIX／Fear&Greed 要不要各自成強型別欄位。
4. **延續性檢索的觸發條件**：每檔都撈，還是只在偵測到「立場可能反轉」時撈（省 token）。
5. **eval 黃金集 15 題挑選標準**：權威文件的 M0 前置待決項，Sean 補完 RAG eval 功課後定。

---

## 附：與權威文件的對應關係

| 本文件 | 對應權威文件 |
|---|---|
| §1 模組地圖（六模組） | §5 功能規格（五元件）＋ 本文件多拆 `corpus/` |
| §3 資料契約 | 權威文件無——這是本文件補的核心缺口 |
| §4 待決登記 #1–5 | 權威 §5.2 M2 進庫機制五要素的具體化 |
| §5 D3（R0） | 權威 §7 R0 里程碑 |
| §5 D5（廠商中立） | 權威 §4 廠商中立原則 |
