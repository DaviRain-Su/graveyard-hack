# 0xchat-Solana — Web3 SuperApp: Nostr Chat × Solana Ecosystem

<p align="center">
  <img src="https://img.shields.io/badge/Solana-Graveyard_Hack-purple?style=for-the-badge&logo=solana" />
  <img src="https://img.shields.io/badge/Flutter-iOS_&_Android-blue?style=for-the-badge&logo=flutter" />
  <img src="https://img.shields.io/badge/Nostr-Decentralized-orange?style=for-the-badge" />
</p>

> **A privacy-first super app that integrates Solana's best protocols — Tapestry, Audius, KYD Labs, Torque, and DRiP — into a real Nostr messaging client.**

Built on [0xchat](https://github.com/0xchat-app/0xchat-app-main) (MIT license), a production-grade Nostr client with 200K+ lines of code, E2E encrypted messaging, group chats, voice/video calls, and Cashu e-cash. We added **14,400+ lines of Dart** integrating five Solana ecosystem protocols as first-class citizens inside private conversations.

---

## 🎯 What We Built

### The Vision: "Web3 WeChat"

| Layer | WeChat / Telegram | **0xchat-Solana** |
|-------|-------------------|-------------------|
| Messaging | Private servers | **Nostr Relay** (decentralized, censorship-resistant) |
| Social Graph | Platform-owned | **Tapestry** (on-chain, composable, portable) |
| Payments | WeChat Pay / TON | **SOL/SPL transfers** (instant, <$0.01 fees) |
| Music | QQ Music / Spotify | **Audius** (decentralized streaming, artist-owned) |
| Events | Mini Programs | **KYD Labs** (Solana-powered ticketing) |
| Rewards | Points (non-transferable) | **Torque** (on-chain loyalty, tradeable tokens) |
| Identity | Phone number (surveilled) | **Nostr keypair + Solana wallet** (self-sovereign) |

### Key Innovation: Nostr → Solana Identity Bridge

Since Nostr (secp256k1) and Solana (ed25519) use different key curves, we created a **deterministic derivation**:

```
SHA-512("oxchat-solana-derive:" + nostrPrivateKey) → first 32 bytes → Ed25519 seed → BIP44 m/44'/501'/0'/0'
```

**Same Nostr key = same Solana address. Always.** No mnemonic backup needed. One identity, two ecosystems.

---

## 🏆 Hackathon Tracks

### 🔗 Track 1: Tapestry — On-Chain Social Graph ($5K)

**Full Tapestry API integration** with auto-binding:

- **`findOrCreate` Profile** — Wallet creation automatically registers on Tapestry with Nostr pubkey
- **Follow/Unfollow** — On-chain social graph, discoverable across all Tapestry apps
- **Content Publishing** — Share NFTs, transactions, music to on-chain feed
- **Likes & Comments** — On-chain reactions using Tapestry's content system
- **Friend Discovery** — Search profiles, suggested friends, social counts
- **Nostr ↔ Solana Resolution** — Look up any Nostr user's Solana address via Tapestry

Files: `tapestry_service.dart` (910 lines), `tapestry_social_page.dart` (1268 lines)

### 🎵 Track 2: Audius — Decentralized Music ($3K)

**Full music experience integrated into chat:**

- 🎧 **Inline Player** — Search, browse trending, play tracks without leaving the app
- 🎸 **Genre Browsing** — Electronic, Hip-Hop, Pop, Lo-Fi, and 10+ genre filters
- 🌍 **Background Playback** — Music keeps playing across all pages (like WeChat mini-program)
- 🎵 **Floating Mini Player** — Persistent bottom bar with spinning album art, play/pause, progress
- 💬 **Chat Sharing** — Pick a track → one-tap "Send" → rich message in conversation
- 📱 **Lock Screen Playback** — iOS audio session configured for background mode
- ▶️ **Auto-Queue** — Finish a track → next one plays automatically

Files: `audius_service.dart`, `audius_player_service.dart` (global singleton), `audius_page.dart`, `floating_music_player.dart`

### 🎟️ Track 3: KYD Labs — Event Ticketing ($5K)

**Solana-powered event discovery inside chat:**

- 📅 **Event Browser** — Recommended events, search, event details with hero images
- 💬 **Chat Sharing** — `🎫 Event` button in chat "+" menu → pick event → send rich message
- 📆 **Add to Calendar** — One-tap Google Calendar integration from event details
- 🎫 **Ticket Info** — Prices, sold-out status, waitlist, venue + map
- ◎ **NFT Ticket Badge** — Highlights events with Solana NFT tickets
- 🔍 **API Reverse-Engineered** — Full KYD API mapped: `/events/recommended`, `/events/{id}`, `/events/{id}/cart`, `/events/{id}/checkoutv2`

Files: `kyd_service.dart` (465 lines), `kyd_events_page.dart` (880+ lines)

### 🏅 Track 4: Torque — Loyalty & Rewards ($1K)

- ⚡ **Quest System** — Browse and complete on-chain campaigns
- 🎁 **Reward Tracking** — Points, achievements, leaderboard
- 📊 **Campaign Discovery** — Integration with Torque's campaign API

Files: `torque_service.dart` (569 lines), `torque_quests_page.dart` (681 lines)

### 🖼️ Track 5: DRiP / NFT ($2.5K)

- 🎨 **NFT Gallery** — 3 tabs: All NFTs / 💧 DRiP Collection / 🔍 Discover
- 💧 **DRiP Integration** — Auto-detect DRiP collectibles, branded collection view
- 🔍 **Drop Discovery** — Browse recent DRiP drops, one-tap collect via drip.haus
- 💬 **Chat Sharing** — Pick NFT from gallery → send as rich message with image + explorer link
- 🔗 **On-chain Metadata** — Full metadata parsing including IPFS artwork resolution, cNFT support

Files: `nft_service.dart` + `DripService` (integrated), `nft_gallery_page.dart`

---

## 💬 Chat-Native Integration

All Solana features are accessible from the chat **"+"** menu:

| Button | Feature | How it works |
|--------|---------|--------------|
| 🧧 SOL Red Packet | Send SOL as a red envelope | Group & 1-on-1 chats |
| 🖼️ NFT | Share NFT from wallet | Opens picker → sends text with image + explorer link |
| 🎵 Music | Share Audius track | Opens picker → one-tap Send → music card in chat |
| 🎫 Event | Share KYD event | Opens event browser → pick → sends event card |
| 💸 SOL Transfer | Send SOL to chat partner | Auto-resolves Nostr pubkey → Solana address via Tapestry |
| ⚡ Zaps | Lightning zaps | Native Nostr zaps (inherited from 0xchat) |

---

## 💰 Solana Wallet

Full-featured wallet built into the messaging app:

- **Create / Import / Nostr-Derive** — Three ways to get a Solana wallet
- **SOL + SPL Tokens** — Balance display, token list with prices (CoinGecko)
- **Send / Receive** — QR code sharing, address validation, transaction history
- **Jupiter DEX Swap** — Token swapping via Jupiter Aggregator API
- **Mainnet + Devnet** — One-tap network switching with airdrop faucet on devnet
- **DApp Connect** — WebView bridge for Solana dApp interaction

---

## 🔒 Privacy Advantage

| Dimension | 0xchat-Solana | Telegram | WhatsApp |
|-----------|---------------|----------|----------|
| Default E2EE | ✅ All chats | ❌ Only Secret Chat | ✅ All chats |
| Metadata Protection | ✅ No central server | ❌ Server collects | ❌ Meta collects |
| Phone Number Required | ❌ Key-based login | ✅ Required | ✅ Required |
| Censorship Resistance | ✅ Relay network | ⚠️ Can ban | ❌ Meta controls |
| Data Ownership | ✅ Self-sovereign | ❌ Platform owns | ❌ Platform owns |
| **On-chain Payments** | ✅ SOL native | ⚠️ TON | ❌ None |
| **On-chain Social** | ✅ Tapestry | ❌ None | ❌ None |

**Signal-level privacy + Telegram-level features + on-chain finance = 0xchat-Solana**

---

## 🏗️ Architecture

```
0xchat-app (200K+ lines, MIT)              ox_solana module (13,800+ lines, new)
──────────────────────────                  ─────────────────────────────────────
✅ E2E Encrypted DMs (NIP-04/17/44)        📦 Solana Wallet (Ed25519, BIP44)
✅ MLS Group Encryption                       ├── SOL/SPL Token Management
✅ Voice/Video Calls (WebRTC)                 ├── Jupiter DEX Swap
✅ Cashu eCash Wallet                         ├── Transaction History
✅ Social Feed (Nostr kind:1)                 └── QR Receive / Send
✅ Multi-Relay Management
✅ Push Notifications                       📦 Tapestry Social Graph
✅ 5-Language i18n                             ├── On-chain Profile
                                               ├── Follow/Unfollow
                                               ├── Content Publishing
                                               └── Friend Discovery

                                            📦 Audius Music
                                               ├── Search + Genre Browse
                                               ├── Global Background Player
                                               ├── Floating Mini Player
                                               └── Chat Sharing

                                            📦 KYD Events + Torque Rewards + NFT Gallery
```

### Module System

0xchat uses a modular architecture where `ox_solana` registers via `OXFlutterModule`:

```dart
// app_initializer.dart — one line to add an entire ecosystem
OXSolana().setup(),  // ← This single line brings in Solana, Tapestry, Audius, KYD, Torque, NFTs
```

Cross-module communication uses `OXModuleService.invoke()` — chat module can call wallet functions without import dependencies.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.x
- Xcode 16+ (for iOS)
- A Tapestry API key (free at [app.usetapestry.dev](https://app.usetapestry.dev))

### Build & Run

```bash
# Clone with submodules
git clone --recursive https://github.com/DaviRain-Su/graveyard-hack.git
cd graveyard-hack/0xchat-solana

# Configure API keys
cp packages/base_framework/ox_common/lib/const/common_constant_example.dart \
   packages/base_framework/ox_common/lib/const/config/common_constant_0xchat.dart
# Edit the config file to add your Tapestry API key

# Install dependencies
flutter pub get

# Run on iOS
flutter run --release

# Or build for real device
flutter build ios --release
```

### Devnet Testing

1. Open the app → Wallet tab
2. Tap settings gear → Switch to **Devnet**
3. Tap **"Request Airdrop"** to get free test SOL
4. Send a test transaction to verify the full flow

---

## 📁 Project Structure

```
packages/business_modules/ox_solana/
├── lib/
│   ├── ox_solana.dart              # Module entry (extends OXFlutterModule)
│   ├── page/
│   │   ├── solana_wallet_page.dart # Main wallet UI (1612 lines)
│   │   ├── audius_page.dart        # Music player + picker (908 lines)
│   │   ├── tapestry_social_page.dart # Social hub (1268 lines)
│   │   ├── kyd_events_page.dart    # Event browser (805 lines)
│   │   ├── torque_quests_page.dart # Quest system (681 lines)
│   │   ├── swap_page.dart          # Jupiter swap UI
│   │   ├── nft_gallery_page.dart   # NFT browser + picker
│   │   ├── send_sol_page.dart      # Send SOL/tokens
│   │   ├── receive_page.dart       # QR code display
│   │   └── ...
│   ├── services/
│   │   ├── solana_wallet_service.dart  # Keypair mgmt, RPC, transfers (768 lines)
│   │   ├── tapestry_service.dart       # Full Tapestry API (910 lines)
│   │   ├── audius_service.dart         # Audius API + models
│   │   ├── audius_player_service.dart  # Global music player singleton
│   │   ├── kyd_service.dart            # KYD Labs API
│   │   ├── torque_service.dart         # Torque campaign API
│   │   ├── jupiter_service.dart        # Jupiter swap quotes
│   │   ├── nft_service.dart            # Helius NFT API
│   │   ├── price_service.dart          # CoinGecko prices
│   │   └── ...
│   └── widgets/
│       ├── floating_music_player.dart  # Persistent bottom player
│       └── token_list_widget.dart      # SPL token list
└── assets/locale/                      # i18n: en, zh, ja, ko, es
```

---

## 🙏 Credits

- **[0xchat](https://github.com/0xchat-app/0xchat-app-main)** — The incredible open-source Nostr client we built upon (MIT license)
- **[Tapestry](https://usetapestry.dev)** — On-chain social graph protocol
- **[Audius](https://audius.co)** — Decentralized music streaming
- **[KYD Labs](https://kydlabs.com)** — Solana-powered event ticketing
- **[Torque](https://torque.so)** — On-chain loyalty & rewards
- **[Helius](https://helius.dev)** — Solana RPC + NFT API
- **[Jupiter](https://jup.ag)** — DEX aggregator

---

## 📄 License

This project is built on 0xchat (MIT License). The `ox_solana` module and all new code is also MIT Licensed.

---

<p align="center">
  <b>Built with ❤️ for Solana Graveyard Hackathon 2026</b><br>
  <i>One app. Five protocols. Zero compromise on privacy.</i>
</p>
