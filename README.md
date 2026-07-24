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
- Provides a rich **Gamification Hub** with interactive mini-games to manage anxiety and focus
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
| **Offline-First** | Full functionality (emotion, intent, LLM chat, games) works with zero internet |
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
| On-Device LLM | `fllama ^0.0.1` | llama.cpp compiled via fllama Android JNI binding |
| ONNX Runtime | `onnxruntime ^1.4.1` | Runs emotion, intent, and burnout models |
| Speech-to-Text | `speech_to_text` (any) | On-device STT via Android speech API, Whisper fallback |
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
│  ┌──────────┐ ┌────────┐ ┌──────────┐ ┌─────────┐ ┌───────────────┐ │
│  │   Chat   │ │ Dash-  │ │  Tasks   │ │ Gamifi- │ │  Assessment   │ │
│  │  Screen  │ │ board  │ │  Screen  │ │ cation  │ │    Screen     │ │
│  └────┬─────┘ └───┬────┘ └────┬─────┘ └────┬────┘ └───────┬───────┘ │
│       └───────────┴───────────┴────────────┴──────────────┘         │
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
│                   ┌──────────────────────────────────────┐          │
│                   │  Whisper base (encoder + decoder)    │          │
│                   │  int8 ONNX — 160MB total             │          │
│                   └──────────────────────────────────────┘          │
├─────────────────────────────────────────────────────────────────────┤
│                         SERVICES LAYER                              │
│  Auth │ Encryption │ Database │ CWS │ Burnout │ Personalization     │
│  Cloud Sync │ Notifications │ Gamification (Games/XP) │ Context     │
├─────────────────────────────────────────────────────────────────────┤
│                         STORAGE LAYER                               │
│  SQLite (utkarsh_v2.db v12) — All messages encrypted AES-256-GCM   │
│  Android Keystore (PIN hash, KDF salt) │ Supabase (optional sync)   │
└─────────────────────────────────────────────────────────────────────┘
```

*(Note: Layer 8 is reserved for future biometric/wearable integration. Assets like `wearable_stress.onnx` and `stress_predictor.tflite` are bundled but intentionally left unused in the current pipeline.)*

---

## 🔄 9-Layer AI Pipeline

### Layer 1 — Input Capture (`lib/pipeline/layer1_input/`)
**What it does:** Captures raw user input in multiple modalities.
- **Text input**: Direct keyboard entry via `TextEditingController`
- **Voice input**: Converted via `SpeechService` (Android on-device STT → text string)
- **Normalization**: Strips excess whitespace, validates non-empty payload

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

**Tier 3 — Keyword Fallback (always available):**
- Hardcoded negative/positive keyword lists

### Layer 3 — Intent Classification (`lib/services/intent/intent_service.dart`)
**What it does:** Classifies the *purpose* of the user's message into one of 6 intent classes.
*(Classes: stressHelp, taskAdd, taskUpdate, planning, knowledgeQuery, casual)*

**Tier 1 — Rule Engine:** Keyword phrase matching with multi-hit scoring (≥0.80 confidence short-circuits)
**Tier 2 — Zero-Shot NLI ONNX:** `intent.onnx` — a RoBERTa-NLI model (64 MB)
**Tier 3 — LLM Fallback:** Prompts LLM for JSON intent classification.

### Layer 4 — Behavior Analysis (`lib/services/behavior/`)
**What it does:** Tracks behavioral events over time and surfaces patterns.
- Logs discrete behavioral events (task completion, mood check-in, engagement patterns)
- Detects flags: `overload`, `procrastination`, `social_withdrawal`

### Layer 5 — Task Engine (`lib/services/tasks/`)
**What it does:** Manages the full task lifecycle and computes task completion score.
- **Task Extraction from Chat:** If intent is `taskAdd`, the AI extracts task title from message
- **Stress-Adjusted Prioritization:** If `stressLevel > 70`, task `priority_score` is lowered and `stress_adjusted = true`

### Layer 6 — Composite Wellbeing Score (`lib/services/cws/cws_engine.dart`)
**What it does:** Computes a single holistic wellbeing index from 7 weighted dimensions.

**CWS Formula:**
```
CWS = (emotionScore × 0.25) + ((100 - stressLevel) × 0.15) + (taskScore × 0.15) 
    + (activityScore × 0.10) + (routineScore × 0.10) + (behaviorScore × 0.15) + (growthScore × 0.10)
```

**Risk Levels:**
| CWS Score | Risk | Color |
|---|---|---|
| 75–100 | 🟢 Green — Healthy | Green |
| 50–74 | 🟡 Yellow — Mild Stress | Yellow |
| 30–49 | 🟠 Orange — Moderate Burnout Risk | Orange |
| 0–29 | 🔴 Red — Severe Burnout | Red |

### Layer 7 — Decision Engine (`lib/services/decision/decision_engine.dart`)
**What it does:** The routing intelligence that decides *which AI model* responds based on offline state, internet availability, and LLM load status.

### Layer 8 — (Reserved for future biometric integration)
*(Intentionally bypassed in the current build)*

### Layer 9 — Response Generation (`lib/pipeline/layer9_response/llm_service.dart`)
**What it does:** Executes actual text generation from the on-device LLM via llama.cpp or Groq Cloud via REST API.

---

## 🤖 All Models — Detailed

### 1. `utkarsh_llm.gguf` — Primary On-Device LLM
| Property | Value |
|---|---|
| Base Model | `meta-llama/Llama-3.2-1B-Instruct` |
| Fine-Tuning | LoRA (rank=16, alpha=32) trained on EmoSApp counseling dataset |
| File Size | ~770 MB (full) / ~300 MB (tiny variant) |
| Runtime | `fllama ^0.0.1` |

### 2. `emotion.onnx` — Sentiment Emotion Classifier
| Property | Value |
|---|---|
| Base Model | `twitter-roberta-base-sentiment-latest` |
| Output | 3-class: `[negative, neutral, positive]` |
| File Size | ~120 MB |
| Runtime | ONNX Runtime (`onnxruntime ^1.4.1`) |

### 3. `intent.onnx` — Zero-Shot Intent Classifier
| Property | Value |
|---|---|
| Base Model | RoBERTa-based NLI model |
| File Size | ~64 MB |

### 4. `burnout.onnx` — Burnout Dimension Analyzer
| Property | Value |
|---|---|
| Base Model | `go_emotions` RoBERTa (Google's 28-class emotion model) |
| Output | 28 emotion probabilities mapped to 5 Maslach Burnout Inventory dimensions |
| File Size | ~476 MB |

### 5. Whisper Base — On-Device Speech Recognition
| Property | Value |
|---|---|
| Base Model | OpenAI Whisper Base (INT8 ONNX quantized) |
| Components | `base-encoder.int8.onnx` (28MB) + `base-decoder.int8.onnx` (124MB) + `base-tokens.txt` |

*(Note: `wearable_stress.onnx` and `stress_predictor.tflite` are provided in `assets/models/` for future integration into Layer 8, but are not actively executed in the pipeline).*

---

## ⚙️ Services Layer

- **`AuthService`:** Manages Supabase authentication + PIN-based encryption key setup.
- **`EncryptionService`:** AES-256-GCM end-to-end encryption for all stored data. PBKDF2-SHA256 derivation.
- **`DatabaseService`:** SQLite data access layer (v12 schema).
- **`EmotionService`, `IntentService`, `BurnoutService`:** Wrappers around ONNX runtime.
- **`CWSEngine`:** Composite Wellbeing Score computation + 7-day smoothing.
- **`DecisionEngine`:** AI routing logic.
- **`PersonalizationEngine`:** Builds dynamic system prompts tailored to user profile.
- **`ContextBuilderService`:** Builds `ContextCapsule` — a 7-day behavioral summary injected into AI prompts.
- **`XPService`:** Gamification progression (Awareness 🌱 to Flourishing ✨).

---

## 🗄 Data Layer & Database Schema

**Database File:** `utkarsh_v2.db` (SQLite, schema version 12)

Core tables include:
- `messages`: All chat messages (content is **AES-256-GCM encrypted** on device).
- `wellbeing_records`: Daily CWS scores and breakdowns.
- `tasks`: Stress-adjusted to-do lists.
- `user_profile`: Demographics, academic context, and preferences.
- `assessments`: Structured wellbeing assessment results.
- `context_capsules`: Weekly behavioral summaries.
- `xp_events` & `behavior_events`: For gamification and tracking.

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

- ✅ **Chat messages** → encrypted on device before SQLite write → never sent to Supabase
- ✅ **AI Inference** → runs 100% on-device (ONNX / llama.cpp)
- ✅ **Supabase** → only stores KDF salt and verification blobs, NO chat content.

---

## ✨ Features

### 🤖 AI Chat (`lib/features/chat/`)
- Real-time streaming response from on-device LLM or Groq
- Automatic emotion + intent analysis per message
- Avatar animation (Lottie) reactive to emotional state

### 🎮 Gamification Hub (`lib/features/gamification/`)
A dedicated suite of interactive, stress-relieving mini-games ported from Utkarsh Velora:
- **Focus Timing Game**: Tests presence of mind and reaction times.
- **Breathing Exercise**: Guided box-breathing to regulate heart rate and panic.
- **Bubble Pop Game**: Casual stress relief.
- **Color Match Game**: Cognitive load testing and refocusing.
- **Tap Timing Game**: Rhythm and consistency training.

### 📊 Dashboard (`lib/features/dashboard/`)
- Composite Wellbeing Score (CWS) donut chart and 7-day trend line
- Daily check-in prompt and **Gamification Quick Access**
- Streak counter + XP progress bar

### ✅ Tasks (`lib/features/tasks/`)
- Stress-adjusted priority scoring and subtask decomposition.
- Extracted automatically from natural language conversations.

### 📈 Growth (`lib/features/growth/`)
- XP history, level visualization, and weekly streaks.

### 📝 Assessment (`lib/features/assessment/`)
- Daily mood & stress check-ins + GAD-7 / PHQ-9 proxies.

### 🔐 Auth (`lib/features/auth/`)
- Multi-device restore + auto PIN-unlock integration.

---

## 📦 State Management

Uses **Riverpod v2** (`flutter_riverpod ^2.5.1`) via `ProviderScope` at app root.
All heavy ML services use a **singleton pattern** (`ServiceName.instance`) to avoid expensive re-initialization during rebuilds.

---

## 🧭 Navigation & Routing

Uses **go_router v13** + named `MaterialApp.routes` for legacy compatibility.
Route map includes paths for `/login`, `/home` (AppShell), `/profile`, and all `/gamification/*` nested interactive screens.

---

## ☁️ Cloud Sync (Optional)

Supabase is used **only** as a secure backup — no AI processing occurs in the cloud. Sync encrypts all data locally before upload, and uses the derived `kdf_salt` to restore access on fresh installs.

---

## 🏋️ Model Training Pipeline

The primary LLM (`utkarsh_llm.gguf`) is trained using `scripts/finetune_emosapp.py` via LLaMA 3.2-1B-Instruct, loaded in 4-bit NF4, fine-tuned with LoRA on an EmoSApp dataset, and finally exported to Q4_K_M GGUF via llama.cpp.

**libllama.so Build** (`scripts/build_libllama.ps1`):
- Compiled using NDK 28.2 + CMake for `arm64-v8a`.

---

## 📁 Project Structure

```
utkarsh_ai/
├── lib/
│   ├── main.dart                  # Entry point
│   ├── app.dart                   # UtkarshApp widget + AuthWrapper
│   ├── models/                    # Data classes (Emotion, Intent, ContextCapsule)
│   ├── pipeline/                  # Layers 1-7, 9 implementations
│   ├── services/                  # Business logic (Auth, Encryption, Decision, etc)
│   ├── features/
│   │   ├── auth/         
│   │   ├── onboarding/   
│   │   ├── chat/         
│   │   ├── dashboard/    
│   │   ├── gamification/          # Interactive mini-games and hubs
│   │   ├── tasks/        
│   │   ├── growth/       
│   │   ├── assessment/   
│   │   ├── settings/     
│   │   └── setup/        
│   ├── core/                      # Theme, constants, shared widgets
│   ├── navigation/                # Router configurations
│   └── state/                     # Global state providers
├── assets/
│   ├── lottie/                    # Avatar Lottie animations
│   └── models/                    # Bundled ONNX, GGUF, and TFLite files
├── scripts/                       # LLM fine-tuning and CMake scripts
├── android/                       # Contains pre-built libllama.so via NDK
└── pubspec.yaml                   
```

---

## 🚀 Setup & Build

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

### 3. Build
```bash
flutter run
flutter build apk --release
```

---

## 🔑 Environment Configuration

The app uses `.env` variables (`GROQ_API_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`). **All core AI features work with zero API keys** — fallback models and local persistence will simply take over.

---

*Built with ❤️ for Indian students facing academic stress — privacy first, always.*
