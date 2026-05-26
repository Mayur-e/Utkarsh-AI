# 🌿 Utkarsh AI — Privacy-First On-Device Behavioral Wellness Companion

> **Version:** 2.0.0 | **Platform:** Android (Flutter) | **Architecture:** On-Device AI + Optional Cloud Fallback

Utkarsh is a **privacy-first, on-device AI behavioral wellness companion** built for Indian students and working professionals. It uses a multi-layer AI inference pipeline to analyze emotion, intent, behavior, and stress in real time — entirely on the user's device — without sending any personal conversation data to external servers.

---

## 📋 Table of Contents

1. [Project Overview](#-project-overview)
2. [Core Philosophy](#-core-philosophy)
3. [Tech Stack](#-tech-stack)
4. [System Architecture](#-system-architecture)
5. [9-Layer AI Pipeline](#-9-layer-ai-pipeline)
6. [All Models — Detailed](#-all-models--detailed)
7. [Services Layer](#-services-layer)
8. [Data Layer & Database Schema](#-data-layer--database-schema)
9. [Security & Privacy Architecture](#-security--privacy-architecture)
10. [Features](#-features)
11. [State Management](#-state-management)
12. [Navigation & Routing](#-navigation--routing)
13. [Cloud Sync (Optional)](#-cloud-sync-optional)
14. [Model Training Pipeline](#-model-training-pipeline)
15. [Project Structure](#-project-structure)
16. [Setup & Build](#-setup--build)
17. [Environment Configuration](#-environment-configuration)

---

## 🌍 Project Overview

Utkarsh is a mobile AI companion that:

- Detects **emotion** (happy, sad, anxious, stressed, neutral, angry) from natural language
- Classifies **intent** (stress help, task add, planning, knowledge query, casual) in every message
- Predicts **burnout risk** using the Maslach Burnout Inventory proxy model
- Computes a **Composite Wellbeing Score (CWS)** across 7 behavioral dimensions
- Manages **tasks** with stress-adjusted prioritization
- Runs a **fine-tuned LLaMA 3.2-1B LLM** on-device using `llama.cpp` for empathetic responses
- Falls back to **Groq Cloud API** (LLaMA 3.3-70B) when online
- Encrypts **every message on device** with AES-256-GCM, key derived from user PIN
- Optionally syncs encrypted data to **Supabase** for multi-device restore

---

## 🧭 Core Philosophy

| Principle | Implementation |
|---|---|
| **Privacy by Default** | All AI inference runs on-device; no chat data ever leaves the phone |
| **Zero-Knowledge Design** | PIN never leaves device; only a PBKDF2-derived key is used for encryption |
| **Offline-First** | Full functionality (emotion, intent, LLM chat) works with zero internet |
| **Graceful Degradation** | ONNX → LLM → keyword rule fallback at every inference step |
| **Student-Centric** | Fine-tuned on EmoSApp counseling dataset; understands Indian academic stress |

---

## 🛠 Tech Stack

### Application Framework
| Layer | Technology | Version |
|---|---|---|
| Mobile Framework | Flutter (Dart) | `>=3.10.0` |
| Dart SDK | Dart | `>=3.0.0 <4.0.0` |
| Target Platform | Android (arm64-v8a) | Min SDK 21 |

### AI / ML Inference
| Component | Technology | Details |
|---|---|---|
| On-Device LLM | `llama_cpp_dart` (git master) | llama.cpp compiled as `libllama.so` via NDK 28.2 |
| ONNX Runtime | `onnxruntime ^1.4.1` | Runs emotion, intent, burnout, wearable-stress models |
| TFLite | Built-in (asset) | `stress_predictor.tflite` — wearable stress fallback |
| Speech-to-Text | `speech_to_text` (any) | On-device STT via Android speech API |
| Text-to-Speech | `flutter_tts ^4.0.2` | On-device TTS output |

### Networking & Cloud
| Component | Technology |
|---|---|
| Cloud AI Fallback | Groq API (`api.groq.com`) — LLaMA 3.3-70B |
| Cloud Auth & Sync | Supabase (`supabase_flutter ^2.12.2`) |
| HTTP Client | `http ^1.2.1` |
| Large File Download | `dio ^5.4.0` (streaming, progress callbacks) |
| Connectivity | `connectivity_plus ^6.0.3` |

### Storage & Security
| Component | Technology |
|---|---|
| Local Database | SQLite via `sqflite ^2.3.2` (schema v12) |
| Secure Key Store | `flutter_secure_storage` — Android Keystore / iOS Keychain |
| Encryption | `cryptography ^2.7.0` — AES-256-GCM |
| KDF | PBKDF2-SHA256, 100,000 iterations |
| Hashing | `crypto ^3.0.3` |

### UI & UX
| Component | Technology |
|---|---|
| State Management | `flutter_riverpod ^2.5.1` |
| Navigation | `go_router ^13.2.0` + named routes |
| Animations | `lottie ^3.1.0` (avatar) |
| Charts | `fl_chart ^0.68.0` (wellbeing trends) |
| Icons | `lucide_icons ^0.257.0` |
| Fonts | `google_fonts ^8.0.2` |
| Notifications | `flutter_local_notifications ^17.2.1` |
| PIN Input | `pinput ^4.0.0` |
| Environment | `flutter_dotenv ^5.1.0` |

---

## 🏗 System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        UTKARSH AI — v2.0                            │
│                  Flutter Mobile App (Android)                       │
├─────────────────────────────────────────────────────────────────────┤
│                         PRESENTATION LAYER                          │
│  ┌──────────┐ ┌────────┐ ┌──────────┐ ┌────────┐ ┌─────────────┐ │
│  │   Chat   │ │ Dash-  │ │  Tasks   │ │ Growth │ │ Assessment  │ │
│  │  Screen  │ │ board  │ │  Screen  │ │ Screen │ │   Screen    │ │
│  └────┬─────┘ └───┬────┘ └────┬─────┘ └───┬────┘ └──────┬──────┘ │
│       └───────────┴───────────┴───────────┴────────────┘          │
│                        STATE (Riverpod)                            │
├─────────────────────────────────────────────────────────────────────┤
│                         9-LAYER AI PIPELINE                         │
│                                                                     │
│  L1: Input Capture → L2: Emotion → L3: Intent → L4: Behavior       │
│       ↓                  ↓             ↓              ↓             │
│  L5: Task Engine → L6: CWS Engine → L7: Decision Engine            │
│                                         ↓                           │
│                              L9: Response (LLM/Groq/Template)       │
├─────────────────────────────────────────────────────────────────────┤
│                         ON-DEVICE AI MODELS                         │
│  ┌──────────────┐ ┌────────────┐ ┌──────────────┐ ┌─────────────┐ │
│  │ utkarsh_llm  │ │emotion.onnx│ │ intent.onnx  │ │burnout.onnx │ │
│  │  .gguf       │ │(RoBERTa-   │ │(NLI zero-    │ │(go_emotions │ │
│  │(LLaMA 3.2-1B │ │ sentiment) │ │  shot NLI)   │ │ RoBERTa-28) │ │
│  │ Q4_K_M 770MB)│ │  120MB     │ │   64MB       │ │   476MB     │ │
│  └──────────────┘ └────────────┘ └──────────────┘ └─────────────┘ │
│  ┌─────────────────────┐ ┌──────────────────────────────────────┐  │
│  │  wearable_stress    │ │  Whisper base (encoder + decoder)    │  │
│  │  .onnx (257KB)      │ │  int8 ONNX — 160MB total             │  │
│  └─────────────────────┘ └──────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────────┤
│                         SERVICES LAYER                              │
│  Auth │ Encryption │ Database │ CWS │ Burnout │ Personalization     │
│  Cloud Sync │ Notifications │ XP/Gamification │ Context Builder     │
├─────────────────────────────────────────────────────────────────────┤
│                         STORAGE LAYER                               │
│  SQLite (utkarsh_v2.db v12) — All messages encrypted AES-256-GCM   │
│  Android Keystore (PIN hash, KDF salt) │ Supabase (optional sync)   │
└─────────────────────────────────────────────────────────────────────┘
```

### Decision Routing (Online/Offline)

```
User Message
      │
      ▼
┌─────────────┐    online AI disabled?    ┌──────────────────┐
│   Decision  │ ─────────────────────────►│  Offline LLM     │
│   Engine    │                           │  (llama.cpp)     │
│  (Layer 7)  │                           └──────────────────┘
│             │    has internet?           ┌──────────────────┐
│             │ ─────────────────────────►│  Groq Cloud API  │
│             │    (yes, knowledge query) │  LLaMA-3.3-70B   │
│             │                           └──────────────────┘
│             │    has internet + local    ┌──────────────────┐
│             │    model loaded?       ───►│  On-Device LLM   │
│             │                           │  (preferred)     │
│             │    no internet + LLM?  ───►│  On-Device LLM   │
│             │                           └──────────────────┘
│             │    no internet + no LLM   ┌──────────────────┐
│             │ ─────────────────────────►│ Template Fallback│
└─────────────┘                           └──────────────────┘
```

---

## 🔄 9-Layer AI Pipeline

The pipeline processes every user message through 9 sequential layers. Each layer is a dedicated Dart service class with ONNX/LLM/rule fallbacks.

### Layer 1 — Input Capture (`lib/pipeline/layer1_input/`)
**What it does:** Captures raw user input in multiple modalities.
- **Text input**: Direct keyboard entry via `TextEditingController`
- **Voice input**: Converted via `SpeechService` (Android on-device STT → text string)
- **Normalization**: Strips excess whitespace, validates non-empty payload
- **Output**: `String userMessage` → passed to Layer 2

### Layer 2 — Emotion Analysis (`lib/services/emotion/emotion_service.dart`)
**What it does:** Classifies the emotional sentiment of the user's message with a 3-tier cascade.

**Tier 1 — ONNX Inference (Primary):**
- **Model:** `emotion.onnx` — a quantized `twitter-roberta-base-sentiment-latest` model (120 MB)
- **Input:** Tokenized message → `[CLS] tokens [SEP]` → `input_ids` + `attention_mask` tensors, shape `[1, seq_len]`
- **Output:** 3 logits → softmax → probabilities `[negative, neutral, positive]`
- **Stress computation:** `stress = (neg_prob × 80) + (neutral_prob × 20)` → clamped 0–100
- **Emotion mapping:** positive→`happy`, neutral→`neutral`, stress>75→`stressed`, stress>50→`anxious`, else→`sad`

**Tier 2 — LLM Fallback (if ONNX fails):**
- Sends prompt to on-device `LLMService.generate()`
- Parses JSON response: `{"sentiment":"...", "stressLevel": 0-100}`

**Tier 3 — Keyword Fallback (always available):**
- Hardcoded negative/positive keyword lists
- Returns `EmotionResult` with `isFallback=true`, confidence 0.45–0.55

**Output:** `EmotionResult { Emotion sentiment, double stressLevel, double confidence, bool isFallback }`

### Layer 3 — Intent Classification (`lib/services/intent/intent_service.dart`)
**What it does:** Classifies the *purpose* of the user's message into one of 6 intent classes.

**Intent Classes:**
| Class | Description |
|---|---|
| `stressHelp` | User needs emotional support / is distressed |
| `taskAdd` | User wants to add a task / reminder |
| `taskUpdate` | User wants to modify/complete a task |
| `planning` | User wants to plan/schedule/organize |
| `knowledgeQuery` | User is asking an informational question |
| `casual` | Small talk / greetings |

**3-Tier Classification Cascade:**

**Tier 1 — Rule Engine (≥0.80 confidence → short-circuits):**
- Keyword phrase matching with multi-hit scoring
- Example: `['add task', 'remind me', 'to-do']` → `taskAdd` at confidence 0.80+

**Tier 2 — Zero-Shot NLI ONNX:**
- **Model:** `intent.onnx` — a RoBERTa-NLI model (64 MB)
- **Method:** For each of the 6 intent classes, forms a premise+hypothesis pair:
  - `[CLS] user_text [SEP] "This text is about adding a new task" [SEP]`
- Runs 6 inference passes → NLI logits → entailment probability for each class
- Selects class with highest entailment score
- Auto-detects if model accepts `token_type_ids` (RoBERTa-style models do not)

**Tier 3 — LLM Fallback:**
- Prompt: classify intent among the 6 classes, return JSON

**Output:** `IntentResult { IntentClass intent, double confidence, String source }`

### Layer 4 — Behavior Analysis (`lib/services/behavior/`)
**What it does:** Tracks behavioral events over time and surfaces patterns.
- Logs discrete behavioral events (task completion, mood check-in, engagement patterns)
- Events stored in `behavior_events` SQLite table with `event_type`, `intensity`, `metadata`
- `BehaviorScore` (0–100) is fed into CWS Layer 6
- Detects flags: `overload`, `procrastination`, `social_withdrawal`

### Layer 5 — Task Engine (`lib/services/tasks/`)
**What it does:** Manages the full task lifecycle and computes task completion score.
- **Task Extraction from Chat:** If intent is `taskAdd`, the AI extracts task title from message
- **Stress-Adjusted Prioritization:** If `stressLevel > 70`, task `priority_score` is lowered and `stress_adjusted = true`
- **Smart Scheduling:** Tasks have `estimated_minutes`, `scheduled_for`, `snoozed_until`, `deferred_to`
- **Subtask decomposition:** Large tasks split into `List<String> subtasks`
- **Scoring:** `taskScore = (completedToday / totalPending) × (1 - stressLevel/100) × 100`

### Layer 6 — Composite Wellbeing Score (`lib/services/cws/cws_engine.dart`)
**What it does:** Computes a single holistic wellbeing index from 7 weighted dimensions.

**CWS Formula:**
```
CWS = (emotionScore × 0.25)
    + ((100 - stressLevel) × 0.15)
    + (taskScore × 0.15)
    + (activityScore × 0.10)
    + (routineScore × 0.10)
    + (behaviorScore × 0.15)
    + (growthScore × 0.10)
```

**7-Day Exponential Smoothing:**
```
smoothedCWS = (0.7 × todayCWS) + (0.3 × 7dayHistoryAverage)
```

**Risk Levels:**
| CWS Score | Risk | Color |
|---|---|---|
| 75–100 | 🟢 Green — Healthy | Green |
| 50–74 | 🟡 Yellow — Mild Stress | Yellow |
| 30–49 | 🟠 Orange — Moderate Burnout Risk | Orange |
| 0–29 | 🔴 Red — Severe Burnout | Red |

**Context-Aware Weights:** `PersonalizationEngine` adjusts weights:
- Exam period → tasks weight: 0.20, stress weight: 0.20
- High stress triggers (≥3) → emotion weight: 0.30

**LLM Insight Generation:** If LLM is in memory, generates a 1-sentence longitudinal insight based on CWS trend (improving/stable/declining).

### Layer 7 — Decision Engine (`lib/services/decision/decision_engine.dart`)
**What it does:** The routing intelligence that decides *which AI model* responds.

**Decision Paths:**
1. **Path A — Forced Offline** (`onlineAiEnabled=false`): Routes to on-device LLM; if model not downloaded → `__MODEL_NOT_LOADED__` message
2. **Path B — Online Mode with Internet:**
   - `knowledgeQuery` intent → always Groq Cloud (needs up-to-date knowledge)
   - Local LLM in memory → prefer on-device LLM (privacy, speed)
   - No local LLM → Groq Cloud
   - Groq fails → fallback to on-device LLM → fallback to template
3. **Path C — Online Mode, No Internet:**
   - Local LLM available → on-device LLM
   - No LLM → template fallback

**Context Injection:** Injects `stressLevel`, `emotion`, and `ContextCapsule` data into Groq system prompt for personalized responses.

### Layer 8 — (Reserved for future biometric integration)

### Layer 9 — Response Generation (`lib/pipeline/layer9_response/llm_service.dart`)
**What it does:** Executes actual text generation from the on-device LLM.

**Model Initialization:**
- Loads `libllama.so` (NDK 28.2, GGUF v3 compatible)
- Priority: `utkarsh_llm.gguf` (770MB) → `utkarsh_llm_tiny.gguf` (469MB)
- Two adaptive load profiles (mmap + no-mmap fallback)
- Automatic extraction from Flutter assets to app documents directory

**Inference Parameters:**
| Parameter | Value |
|---|---|
| Max tokens | 128 |
| Context size | 512 (low RAM optimization) |
| Threads | 2 |
| Temperature | 0.72 |
| Top-P | 0.9 |
| Repeat penalty | 1.1 |
| Max history turns | 5 |

**Prompt Format (LLaMA 3.2 Instruct):**
```
<|begin_of_text|>
<|start_header_id|>system<|end_header_id|>
[PersonalizationEngine system prompt]
<|eot_id|>
<|start_header_id|>user<|end_header_id|>
[user message]
<|eot_id|>
<|start_header_id|>assistant<|end_header_id|>
[streamed response tokens...]
```

**Streaming:** Tokens streamed via `onToken` callback → real-time display in chat bubble

---

## 🤖 All Models — Detailed

### 1. `utkarsh_llm.gguf` — Primary On-Device LLM
| Property | Value |
|---|---|
| Base Model | `meta-llama/Llama-3.2-1B-Instruct` |
| Fine-Tuning Method | LoRA (rank=16, alpha=32, dropout=0.05) |
| Fine-Tuning Dataset | EmoSApp mental health counseling dataset (seeker/supporter multi-turn) |
| Training Framework | HuggingFace TRL `SFTTrainer` on Google Colab T4 GPU |
| Quantization | Q4_K_M via `llama.cpp convert_hf_to_gguf.py` |
| File Size | ~770 MB (full) / ~469 MB (tiny variant) |
| Runtime | `llama_cpp_dart` → `libllama.so` (NDK 28.2) |
| Context Window | 512 tokens (app-side) |
| Target Layers | `q_proj`, `k_proj`, `v_proj`, `o_proj`, `gate_proj`, `up_proj`, `down_proj` |
| Training Duration | ~2-3 hours on T4 GPU, 3 epochs |
| System Persona | "Utkarsh, warm and caring mental health companion for Indian students" |
| Crisis Reference | iCALL helpline: 9152987821 |

### 2. `emotion.onnx` — Sentiment Emotion Classifier
| Property | Value |
|---|---|
| Base Model | `twitter-roberta-base-sentiment-latest` |
| Architecture | RoBERTa (transformer encoder) |
| Output | 3-class: `[negative, neutral, positive]` |
| Quantization | ONNX (fp32 export) |
| File Size | ~120 MB |
| Input Tensors | `input_ids [1, seq_len]`, `attention_mask [1, seq_len]` |
| Output | Logits `[1, 3]` → softmax → probabilities |
| Stress Score | `neg_prob × 80 + neutral_prob × 20` |
| Runtime | ONNX Runtime (`onnxruntime ^1.4.1`) |

### 3. `intent.onnx` — Zero-Shot Intent Classifier
| Property | Value |
|---|---|
| Base Model | RoBERTa-based NLI model |
| Method | Zero-shot Natural Language Inference (NLI) |
| Output | Entailment probability for each of 6 intent hypotheses |
| File Size | ~64 MB |
| Input | Premise (user text) + Hypothesis (intent description) encoded as NLI pair |
| NLI Labels | `[contradiction=0, neutral=1, entailment=2]` |
| Runtime | ONNX Runtime |

### 4. `burnout.onnx` — Burnout Dimension Analyzer
| Property | Value |
|---|---|
| Base Model | `go_emotions` RoBERTa (Google's 28-class emotion model) |
| Output | 28 emotion probabilities mapped to 5 Maslach Burnout Inventory dimensions |
| File Size | ~476 MB |
| Input | Tokenized text (last 5–10 messages concatenated) |
| Output Dimensions | Exhaustion, Cynicism, Low Efficacy, Anxiety, Sadness |
| Burnout Index | Weighted sum: `exhaustion×1.5 + cynicism + lowEfficacy + anxiety×0.75 + sadness×0.75` |
| Risk Labels | Healthy / Mild stress / Moderate burnout risk / High burnout risk / Severe burnout |

**Label-to-Dimension Mapping:**
| Dimension | go_emotions Labels (index) |
|---|---|
| Exhaustion | grief(16), sadness(25), disappointment(9) |
| Cynicism | annoyance(3), disapproval(10), disgust(11) |
| Low Efficacy | admiration(0), gratitude(15), pride(21) — **INVERTED** |
| Anxiety | fear(14), confusion(6), remorse(24) |
| Sadness | sadness(25), grief(16), disappointment(9) |

### 5. `wearable_stress.onnx` — Wearable Sensor Stress Predictor
| Property | Value |
|---|---|
| Purpose | Predicts stress from wearable sensor inputs (HRV, steps, sleep) |
| File Size | ~257 KB (lightweight) |
| Companion | `stress_scaler.json` — feature normalization parameters |
| Runtime | ONNX Runtime |

### 6. `stress_predictor.tflite` — TFLite Stress Model
| Property | Value |
|---|---|
| Purpose | Alternative lightweight stress prediction (TensorFlow Lite) |
| File Size | ~350 KB |
| Companion | `stress_scaler.json` |

### 7. Whisper Base — On-Device Speech Recognition
| Property | Value |
|---|---|
| Base Model | OpenAI Whisper Base |
| Format | INT8 ONNX (quantized for mobile) |
| Components | `base-encoder.int8.onnx` (28MB) + `base-decoder.int8.onnx` (124MB) |
| Vocabulary | `base-tokens.txt` (~800KB) |
| Tokenizer | `emosapp/tokenizer.bin` (2.1MB) |
| Purpose | Speech-to-text for voice input |

---

## ⚙️ Services Layer

### `AuthService` (`lib/services/auth/auth_service.dart`)
Manages Supabase authentication + PIN-based encryption key setup.
- **Registration:** Creates Supabase account → generates KDF salt → derives AES key from PIN → stores verification blob in Supabase `user_meta` table → migrates local data to new user ID
- **Login:** Supabase auth → fetches KDF salt → re-derives AES key from PIN locally → verifies against encrypted blob → auto-restores cloud backup if local DB is empty
- **Auto-unlock:** On cold start, reads cached PIN from Android Keystore → re-derives key without prompting
- **Manual unlock:** Used from PIN lock screen

### `EncryptionService` (`lib/services/storage/encryption_service.dart`)
AES-256-GCM end-to-end encryption for all stored data.
- **Key Derivation:** PBKDF2-SHA256 (100,000 iterations) from `PIN + salt` → 256-bit key
- **Key Storage:** Only in memory during session; PIN hash in Android Keystore
- **Format:** `nonce_base64:ciphertext_base64:mac_base64`
- **Scope:** All `messages.content` fields encrypted before SQLite insert; decrypted on read
- **Key Lock:** On app background → `lockKey()` clears in-memory key

### `DatabaseService` (`lib/services/storage/database_service.dart`)
SQLite data access layer (v12 schema, singleton pattern).
- **Tables:** `messages`, `wellbeing_records`, `tasks`, `xp_events`, `assessments`, `behavior_events`, `user_profile`, `context_capsules`
- **Encryption:** All message content encrypted via `EncryptionService` before storage
- **Migration:** `migrateLocalData()` moves all `local_user` records to authenticated user ID on first login
- **Multi-user safe:** All queries scoped by `user_id`

### `EmotionService` (`lib/services/emotion/emotion_service.dart`)
3-tier emotion analysis (ONNX → LLM → keyword fallback). See Layer 2.

### `IntentService` (`lib/services/intent/intent_service.dart`)
3-tier zero-shot NLI intent classification. See Layer 3.

### `BurnoutService` (`lib/services/burnout/burnout_service.dart`)
go_emotions-based burnout dimension analysis. See Model #4.

### `CWSEngine` (`lib/services/cws/cws_engine.dart`)
Composite Wellbeing Score computation + 7-day smoothing + LLM insight. See Layer 6.

### `DecisionEngine` (`lib/services/decision/decision_engine.dart`)
AI routing logic. See Layer 7.

### `LLMService` (`lib/pipeline/layer9_response/llm_service.dart`)
On-device LLM inference via llama.cpp. See Layer 9.

### `GroqClient` (`lib/services/decision/groq_client.dart`)
Cloud AI fallback using Groq REST API.
- Endpoint: `https://api.groq.com/openai/v1/chat/completions`
- Model: `llama-3.3-70b-versatile`
- Parameters: temperature 0.7, max_tokens 1024
- Context injection: `PersonalizationEngine.buildSystemPrompt()` + `ContextCapsule` block
- Sends last 8 messages of history

### `PersonalizationEngine` (`lib/services/personalization/personalization_engine.dart`)
Builds dynamic system prompts tailored to user profile.
- Injects: name, age, profession, stream/year (college), stress triggers, social preference
- Communication style: Warm/Direct/Analytical based on `ResponseStyle`
- Language: English / Hindi / Hinglish
- Greeting: Time-of-day + academic context (exam/placement season)
- CWS weight adjustment: exam period, high trigger count

### `ContextBuilderService` (`lib/services/context/context_builder_service.dart`)
Builds `ContextCapsule` — a 7-day behavioral summary injected into AI prompts.
- Aggregates: dominant emotion, average stress, primary intent, consecutive negative days, session themes
- Behavioral flags: `overload`, `procrastination`, `social_withdrawal`
- Session themes (12 types): `academicPressure`, `sleepIssues`, `burnout`, `positiveProgress`, etc.

### `XPService` (`lib/services/growth/xp_service.dart`)
Gamification layer — XP rewards and level progression.

**XP Table:**
| Action | XP |
|---|---|
| `TASK_COMPLETED` | 10 |
| `STRESS_REDUCED` | 15 |
| `WEEKLY_STREAK` | 20 |
| `ASSESSMENT_COMPLETE` | 8 |
| `MOOD_IMPROVED` | 10 |
| `REFLECTION_ADDED` | 5 |
| `DAILY_CHECKIN` | 3 |

**Level Progression:**
| Level | XP Range | Emoji |
|---|---|---|
| Awareness | 0–100 | 🌱 |
| Stabilizing | 100–300 | 🌿 |
| Improving | 300–700 | 🌳 |
| Resilient | 700–1500 | 🌟 |
| Flourishing | 1500+ | ✨ |

### `SpeechService` (`lib/services/input/speech_service.dart`)
Wraps Android `speech_to_text` plugin for voice input. Singleton instance with initialize/listen/stop lifecycle.

### `NotificationService` (`lib/services/notifications/notification_service.dart`)
Push notifications via `flutter_local_notifications`. Schedules evening wellbeing check-in.

### `CloudSyncService` (`lib/services/cloud/cloud_sync_service.dart`)
Optional Supabase sync for multi-device support. Encrypts all data before upload; restores on fresh install.

---

## 🗄 Data Layer & Database Schema

**Database File:** `utkarsh_v2.db` (SQLite, schema version 12)

### `messages`
```sql
CREATE TABLE messages (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL DEFAULT 'local_user',
  role         TEXT NOT NULL CHECK(role IN ('user','assistant','system')),
  content      TEXT NOT NULL,  -- AES-256-GCM encrypted
  timestamp    INTEGER NOT NULL,
  emotion_label TEXT,          -- 'happy','sad','anxious','stressed','neutral','angry'
  stress_level  REAL,          -- 0.0-100.0
  intent_class  TEXT,          -- 'stressHelp','taskAdd',...
  session_id   TEXT NOT NULL
)
```

### `wellbeing_records`
```sql
CREATE TABLE wellbeing_records (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL DEFAULT 'local_user',
  date          TEXT NOT NULL UNIQUE,  -- YYYY-MM-DD
  cws_score     REAL NOT NULL,          -- 0-100 (smoothed)
  emotion_score REAL,
  stress_score  REAL,
  task_score    REAL,
  activity_score REAL,
  routine_score REAL,
  behavior_score REAL,
  growth_score  REAL,
  risk_level    TEXT,                  -- 'green','yellow','orange','red'
  created_at    INTEGER NOT NULL
)
```

### `tasks`
```sql
CREATE TABLE tasks (
  id                TEXT PRIMARY KEY,
  user_id           TEXT NOT NULL DEFAULT 'local_user',
  title             TEXT NOT NULL,
  description       TEXT,
  deadline          INTEGER,            -- ms timestamp
  priority          INTEGER DEFAULT 2,  -- 1=low,2=med,3=high,4=critical
  status            TEXT DEFAULT 'pending',
  category          TEXT DEFAULT 'academic', -- academic|personal|social|professional|...
  complexity        TEXT DEFAULT 'medium',   -- micro|small|medium|large|project
  extracted_from_chat INTEGER DEFAULT 0,
  pre_mood          INTEGER,
  post_mood         INTEGER,
  created_at        INTEGER NOT NULL,
  completed_at      INTEGER,
  snoozed_until     INTEGER,
  deferred_to       INTEGER,
  subtasks          TEXT,               -- pipe-separated micro-steps
  estimated_minutes INTEGER DEFAULT 30,
  scheduled_for     INTEGER,
  priority_score    REAL DEFAULT 50.0, -- stress-adjusted computed score
  stress_adjusted   INTEGER DEFAULT 0
)
```

### `user_profile`
Stores complete `UserProfile` — demographics, academic context, lifestyle, AI preferences, notification prefs, gamification state, emergency contacts.

### `assessments`
Stores structured wellbeing assessment results (GAD-7, PHQ-9, daily mood/stress).

### `context_capsules`
Weekly behavioral summary: dominant emotion, average stress, behavioral flags, session themes, CWS trend.

### `xp_events`
Individual XP award events for gamification history.

### `behavior_events`
Discrete behavioral signals with intensity scores.

---

## 🔐 Security & Privacy Architecture

### Zero-Knowledge Design
```
User PIN (6 digits)
       │
       ▼
PBKDF2-SHA256 (100,000 iterations)
       │
       ▼
256-bit AES-GCM Key ─── (IN MEMORY ONLY) ───► Encrypts all SQLite messages
       │
       │◄─── Cleared on app background
       │
PIN Hash (checksum) ─── Android Keystore ──► Used for PIN verification only
KDF Salt ──────────── Android Keystore + Supabase user_meta ──► Salt restoration
```

### Data Flow (Privacy Guarantee)
- ✅ **Chat messages** → encrypted on device before SQLite write → never sent to Supabase
- ✅ **Emotion/Intent analysis** → runs 100% on-device (ONNX)
- ✅ **LLM response** → runs 100% on-device (llama.cpp)
- ⚡ **Groq Cloud** → only used when: user enables online AI **AND** has internet **AND** (knowledge query or no local LLM)
- ✅ **Supabase** → only stores: `kdf_salt`, `kdf_iters`, `pin_verify_blob`, `schema_ver` — NO chat content

### Encryption Spec
| Spec | Value |
|---|---|
| Algorithm | AES-256-GCM |
| Key Derivation | PBKDF2-SHA256 |
| Iterations | 100,000 |
| Salt Length | 256-bit random |
| Nonce | 96-bit per-message random |
| MAC | 128-bit GCM authentication tag |
| Wire Format | `nonce_b64:ciphertext_b64:mac_b64` |

---

## ✨ Features

### 🤖 AI Chat (`lib/features/chat/`)
- Real-time streaming response from on-device LLM or Groq
- Automatic emotion + intent analysis per message
- Avatar animation (Lottie) reactive to emotional state
- Voice input (STT) + voice output (TTS)
- Task extraction from natural language
- Context-aware responses using 7-day `ContextCapsule`
- AI mode indicator (Offline/Online/Template)

### 📊 Dashboard (`lib/features/dashboard/`)
- Composite Wellbeing Score (CWS) donut chart
- 7-day CWS trend line (fl_chart)
- Risk level indicator with color coding
- Daily check-in prompt
- Streak counter + XP progress bar
- Quick task overview

### ✅ Tasks (`lib/features/tasks/`)
- Full task CRUD with categories and complexity levels
- Stress-adjusted priority scoring
- Snooze and defer functionality
- Subtask decomposition for large tasks
- Pre/post mood tracking per task
- Chat-extracted task detection badge

### 📈 Growth (`lib/features/growth/`)
- XP history and level visualization
- Weekly streak tracking
- Wellbeing trend analysis
- Achievement indicators

### 📝 Assessment (`lib/features/assessment/`)
- Daily mood & stress check-ins
- Structured wellbeing assessments (GAD-7 / PHQ-9 proxies)
- Score history and severity labels
- XP award on completion

### 🔐 Auth (`lib/features/auth/`)
- Email/password registration with Supabase
- 6-digit PIN setup for on-device key derivation
- Auto-unlock on app start
- Multi-device restore from Supabase

### ⚙️ Settings (`lib/features/settings/`)
- Toggle online/offline AI mode
- Clear cached LLM models
- Emergency contacts management
- Notification preferences
- Profile edit
- Debug panel for AI service status

### 🎯 Onboarding (`lib/features/onboarding/`)
- Profession selection (college student, school student, professional, job seeker, researcher)
- Academic context (university, stream, year, upcoming events)
- Lifestyle preferences (wake/sleep time, stress triggers, activity level)
- AI preference setup (response style, language, voice)
- Model download/setup screen

---

## 📦 State Management

Uses **Riverpod v2** (`flutter_riverpod ^2.5.1`) via `ProviderScope` at app root.

**`AppState` (`lib/state/app_state.dart`):**
```dart
enum AiMode { groq, llm, offline }
```
Tracks current AI mode across the app for UI indicators.

All services use **singleton pattern** (`ServiceName.instance` or `serviceNameSingleton`) rather than Riverpod providers for heavy ML services to avoid re-initialization.

---

## 🧭 Navigation & Routing

Uses **go_router v13** + named `MaterialApp.routes` for legacy compatibility.

**Route Map:**
| Route | Screen | Condition |
|---|---|---|
| `/` (home) | `AuthWrapper` → decides initial screen | Always |
| `WelcomeScreen` | Welcome/Login choice | Not logged in |
| `PinUnlockScreen` | PIN entry screen | Logged in but locked |
| `OnboardingFlow` | Multi-step onboarding | First time user |
| `ModelSetupScreen` | Model download / setup | After onboarding, before first use |
| `AppShell` | Main tab navigation | Fully authenticated |
| `/profile` | Profile view | Authenticated |

**`AuthWrapper` boot sequence:**
1. PIN auto-unlock attempt
2. LLM disk presence check (non-blocking)
3. Profile check (onboarding gate)
4. Bundled offline pack auto-detection

---

## ☁️ Cloud Sync (Optional)

Supabase is used **only** as a secure backup — no AI processing occurs in the cloud.

**Supabase Tables:**
| Table | Columns | Purpose |
|---|---|---|
| `user_meta` | `user_id`, `kdf_salt`, `kdf_iters`, `schema_ver`, `pin_verify_blob` | KDF salt + PIN verification blob |

**Cloud Sync flow:**
1. `CloudSyncService.restoreAll()` — called on login to a new device
2. Fetches `kdf_salt` → re-derives local AES key from PIN
3. Downloads and decrypts context capsules / profile from Supabase
4. Restores local SQLite state

---

## 🏋️ Model Training Pipeline

The primary LLM (`utkarsh_llm.gguf`) is trained using `scripts/finetune_emosapp.py`:

```
Step 1: Load EmoSApp dataset (seeker/supporter multi-turn JSON)
         └── Format as LLaMA 3.2 Instruct chat template

Step 2: Load base model: meta-llama/Llama-3.2-1B-Instruct
         └── 4-bit NF4 quantization (BitsAndBytes) for T4 GPU

Step 3: Apply LoRA (rank=16, alpha=32)
         └── Target: q_proj, k_proj, v_proj, o_proj, gate_proj, up_proj, down_proj

Step 4: SFT Training (3 epochs, cosine LR schedule, paged_adamw_8bit)
         └── ~2-3 hours on Google Colab T4 GPU

Step 5: Merge LoRA adapter into base model weights (fp16)

Step 6: Convert merged model → GGUF Q4_K_M via llama.cpp
         └── Output: utkarsh_llm.gguf (~770MB)

Step 7: Place in assets/models/ → flutter build apk
```

**libllama.so Build** (`scripts/build_libllama.ps1`):
- llama.cpp commit `0e4ebeb` (GGUF v3 compatible)
- NDK 28.2 + CMake 3.22.1
- Target: `arm64-v8a`
- Output: `android/app/src/main/jniLibs/arm64-v8a/libllama.so`

---

## 📁 Project Structure

```
utkarsh_ai/
├── lib/
│   ├── main.dart                  # Entry point — sequential boot, background init
│   ├── app.dart                   # UtkarshApp widget + AuthWrapper
│   ├── models/
│   │   ├── user_profile.dart      # UserProfile + nested profiles (College/School/Professional)
│   │   ├── emotion.dart           # Emotion enum (happy|sad|anxious|stressed|neutral|angry)
│   │   ├── intent.dart            # IntentClass enum (6 classes)
│   │   ├── task.dart              # Task model (status/category/complexity/subtasks)
│   │   └── context_capsule.dart   # 7-day behavioral summary model
│   ├── pipeline/
│   │   ├── layer1_input/          # Input capture (placeholder, logic in services)
│   │   ├── layer2_emotion/        # (Implemented in services/emotion/)
│   │   ├── layer3_intent/         # (Implemented in services/intent/)
│   │   ├── layer4_behavior/       # (Implemented in services/behavior/)
│   │   ├── layer5_tasks/          # (Implemented in services/tasks/)
│   │   ├── layer6_cws/            # (Implemented in services/cws/)
│   │   ├── layer7_decision/       # (Implemented in services/decision/)
│   │   └── layer9_response/
│   │       └── llm_service.dart   # On-device LLM (llama.cpp wrapper, streaming)
│   ├── services/
│   │   ├── auth/
│   │   │   ├── auth_service.dart       # Supabase auth + PIN KDF setup
│   │   │   └── key_derivation_service.dart  # PBKDF2 implementation
│   │   ├── storage/
│   │   │   ├── database_service.dart  # SQLite DAO (v12 schema, 8 tables)
│   │   │   └── encryption_service.dart # AES-256-GCM (in-memory key)
│   │   ├── emotion/
│   │   │   └── emotion_service.dart   # ONNX → LLM → keyword cascade
│   │   ├── intent/
│   │   │   └── intent_service.dart    # Rule → NLI ONNX → LLM cascade
│   │   ├── burnout/
│   │   │   └── burnout_service.dart   # go_emotions ONNX → Maslach mapping
│   │   ├── cws/
│   │   │   └── cws_engine.dart        # CWS formula + smoothing + risk levels
│   │   ├── decision/
│   │   │   ├── decision_engine.dart   # AI routing (offline/online/template)
│   │   │   └── groq_client.dart       # Groq REST API client
│   │   ├── personalization/
│   │   │   └── personalization_engine.dart  # System prompt builder
│   │   ├── context/
│   │   │   └── context_builder_service.dart  # ContextCapsule builder
│   │   ├── growth/
│   │   │   └── xp_service.dart        # XP awards + level progression
│   │   ├── cloud/
│   │   │   └── cloud_sync_service.dart # Supabase encrypted backup/restore
│   │   ├── input/
│   │   │   ├── speech_service.dart    # STT via speech_to_text
│   │   │   └── input_capture_service.dart
│   │   ├── avatar/
│   │   │   └── avatar_service.dart    # Lottie avatar emotion state
│   │   ├── notifications/
│   │   │   └── notification_service.dart # Local push notifications
│   │   └── behavior/                  # Behavioral event logging
│   ├── features/
│   │   ├── auth/         # Login, Welcome, PIN unlock screens
│   │   ├── onboarding/   # Multi-step onboarding + model setup
│   │   ├── chat/         # AI chat interface (main screen)
│   │   ├── dashboard/    # CWS dashboard + trends
│   │   ├── tasks/        # Task management screens
│   │   ├── growth/       # XP, levels, streak screens
│   │   ├── assessment/   # Mood + stress assessment screens
│   │   ├── settings/     # App settings + profile screens
│   │   └── setup/        # Model download/setup UI
│   ├── core/
│   │   ├── theme/        # AppTheme (dark theme, color scheme)
│   │   ├── constants/    # App-wide constants
│   │   ├── utils/        # Helpers (todayString, etc.)
│   │   └── widgets/      # Shared UI components
│   ├── navigation/
│   │   └── app_router.dart  # go_router configuration
│   └── state/
│       └── app_state.dart   # Global AiMode enum + Riverpod providers
├── assets/
│   ├── logo.png
│   ├── lottie/              # Avatar Lottie animation JSON files
│   └── models/
│       ├── utkarsh_llm_tiny.gguf     # ~469MB (bundled tiny LLM)
│       ├── emotion.onnx              # ~120MB (RoBERTa sentiment)
│       ├── intent.onnx               # ~64MB (NLI zero-shot)
│       ├── burnout.onnx              # ~476MB (go_emotions)
│       ├── wearable_stress.onnx      # ~257KB
│       ├── stress_scaler.json        # Feature scaler params
│       ├── stress_predictor.tflite   # ~350KB
│       ├── whisper/
│       │   ├── base-encoder.int8.onnx  # ~28MB
│       │   ├── base-decoder.int8.onnx  # ~124MB
│       │   └── base-tokens.txt         # Whisper vocabulary
│       └── emosapp/
│           └── tokenizer.bin           # EmosApp tokenizer (~2.1MB)
├── models_devonly/
│   ├── utkarsh_llm.gguf              # Full 770MB LLM (dev only, not committed)
│   ├── utkarsh_llm_tiny.gguf
│   ├── burnout.onnx
│   └── tts.onnx                      # TTS model (dev exploration)
├── scripts/
│   ├── finetune_emosapp.py           # LoRA fine-tuning pipeline (Colab)
│   ├── convert_emosapp.py            # Model conversion utilities
│   ├── colab_setup.py                # Colab environment setup
│   └── build_libllama.ps1            # libllama.so native build script (Windows)
├── android/                          # Android native project
│   └── app/src/main/jniLibs/
│       └── arm64-v8a/
│           └── libllama.so           # Pre-built llama.cpp native lib
├── pubspec.yaml                      # Flutter dependencies
├── .env                              # API keys (not committed)
└── analysis_options.yaml
```

---

## 🚀 Setup & Build

### Prerequisites
- Flutter SDK `>=3.10.0`
- Android NDK 28.2 (for native llama.cpp build)
- Google Colab T4 (for LLM fine-tuning)

### 1. Clone & Install Dependencies
```bash
git clone <repo-url>
cd utkarsh_ai
flutter pub get
```

### 2. Configure Environment
```bash
cp .env.example .env
# Fill in GROQ_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY
```

### 3. Model Setup
The app handles model extraction automatically on first launch from bundled assets. For development, place models in `assets/models/`.

### 4. Build
```bash
# Debug
flutter run

# Release APK
flutter build apk --release

# Generate icons
flutter pub run flutter_launcher_icons
```

### 5. (Optional) Rebuild libllama.so
```powershell
# From project root
.\scripts\build_libllama.ps1
```

---

## 🔑 Environment Configuration

**`.env` file (not committed to git):**
```env
# Groq Cloud API (optional — used for online AI fallback)
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Supabase (optional — used for auth and encrypted backup)
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**App behavior without keys:**
- No `GROQ_API_KEY` → Online AI disabled; on-device LLM only
- No Supabase keys → Auth disabled; app runs in fully local mode (`local_user` profile)
- **All core AI features work with zero API keys** (emotion, intent, burnout, LLM chat)

---

## 📊 Key Metrics

| Metric | Value |
|---|---|
| Total bundled AI models | 7 models, ~1.65 GB |
| Primary LLM size (full) | ~770 MB (Q4_K_M GGUF) |
| Primary LLM size (tiny) | ~469 MB |
| SQLite schema version | 12 |
| Pipeline layers | 9 |
| Intent classes | 6 |
| Emotion classes | 6 |
| Burnout dimensions | 5 (Maslach Inventory proxies) |
| CWS dimensions | 7 |
| Gamification levels | 5 (Awareness → Flourishing) |
| Min Android SDK | API 21 (Android 5.0) |
| Target architecture | arm64-v8a |

---

*Built with ❤️ for Indian students facing academic stress — privacy first, always.*
