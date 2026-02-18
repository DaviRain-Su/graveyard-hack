# 0xchat-solana — 在 0xchat 上集成 Solana 生态

> Solana Graveyard Hackathon 参赛项目
> 赛道：链上社交 (Tapestry) + 票务 (KYD Labs) + 音乐 (Audius) + 忠诚度 (Torque) + NFT (DRiP)
> 时间：2026-02-12 ~ 2026-02-27（剩余 ~10 天）

---

## 一、项目定位

**一句话描述：** 基于 0xchat 开源 Nostr 客户端进行 Web 端扩展，集成 Solana 五大生态（Tapestry 社交图谱 + SOL 支付 + KYD 票务 + Audius 音乐 + Torque 奖励），打造 Web3 版「微信」超级客户端。

### 为什么这个组合有意义？

| 层级 | 微信/Telegram | 0xchat-solana |
|------|--------------|---------------|
| 消息通信 | 私有服务器 | **Nostr Relay**（去中心化、抗审查） |
| 社交关系 | 平台私有数据 | **Tapestry 链上社交图谱**（Solana 上公开可组合） |
| 支付 | 微信支付/TON | **SOL/SPL Token 转账**（即时、低费） |
| 音乐 | QQ 音乐/Spotify | **Audius**（去中心化音乐流媒体） |
| 活动/服务 | 微信小程序 | **KYD 票务** + 更多链上服务 |
| 积分/奖励 | 积分/会员 | **Torque 忠诚度计划** |
| 身份 | 手机号 | **Nostr 公钥 + Solana 钱包** |

---

## 二、参赛赛道（一个项目 → 五个赛道）

### 🥇 赛道 1：链上社交 — Tapestry（$5K）⭐ 主赛道
- **赞助商：** Tapestry (https://usetapestry.dev)
- **要求：** 使用 Tapestry 协议构建链上社交应用
- **我们做什么：** Nostr 联系人 ↔ Tapestry 链上图谱双向同步，社交 Feed，好友推荐

### 🥈 赛道 2：票务 — KYD Labs（$5K）
- **赞助商：** KYD Labs (https://kydlabs.com)
- **要求：** 基于 KYD 构建下一代票务方案
- **我们做什么：** 聊天内活动发现 + 约好友买票 + 活动群聊

### 🥉 赛道 3：音乐 — Audius（$3K）⭐ 高 ROI
- **赞助商：** Audius (https://audius.co)
- **要求：** 利用 Audius API 赋能艺术家和创作者
- **我们做什么：** 聊天内分享/播放 Audius 音乐，音乐 Feed，群内一起听歌

### 赛道 4：忠诚度 — Torque（$1K）
- **赞助商：** Torque (https://torque.so)
- **要求：** 使用 Torque 构建忠诚度/奖励系统
- **我们做什么：** 群活跃奖励积分，签到得 Token，推荐好友激励

### 赛道 5：NFT — DRiP（$2.5K）
- **赞助商：** DRiP (https://drip.haus)
- **要求：** 积极参与 DRiP 生态
- **我们做什么：** 聊天中发送/领取 NFT 收藏品，群内 NFT 空投

**理论最大奖金：$15K(总奖) + $5K + $5K + $3K + $2.5K + $1K = $31.5K**

---

## 三、技术路径决策

### 🎯 最终方案：Next.js Web 端 + Nostr 协议 + Solana

**放弃 Fork 0xchat Flutter 的理由：**
1. Flutter 编译环境 + 理解 0xchat 代码库 = 至少消耗 3-4 天
2. 0xchat 代码量巨大（5+ 个仓库，数万行 Dart），风险太高
3. Dart 生态的 Solana/Tapestry/Audius SDK 几乎为零
4. Hackathon 评审主要看 Demo 效果 + 创新，不看 App 是否原生

**Web 端优势：**
1. JS/TS 生态全面支持：nostr-tools、@solana/web3.js、socialfi（Tapestry SDK）、Audius API
2. 开发速度快，一个人 10 天可以交付完整 MVP
3. Vercel 一键部署，评审可以直接体验
4. Tapestry 官方模板就是 Next.js（https://github.com/Primitives-xyz/tapestry-template）
5. 可以引用 0xchat 的设计灵感和 Nostr 协议实现，README 里致敬 0xchat

---

## 四、技术架构

### 4.1 技术栈

| 层 | 技术选型 | 说明 |
|----|---------|------|
| 框架 | **Next.js 15 + React 19** | App Router, Server Components |
| UI | **Tailwind CSS 4 + shadcn/ui** | 快速构建, 移动端优先 |
| Nostr | **nostr-tools** | Nostr 协议 SDK |
| Solana | **@solana/web3.js + wallet-adapter** | 钱包连接、交易 |
| 社交图谱 | **socialfi** (Tapestry SDK) | 链上社交图谱 CRUD |
| 音乐 | **Audius REST API** | 搜索/播放/流媒体 |
| 票务 | **KYD Protocol API** | 活动/票务集成 |
| 奖励 | **@torque-labs/torque-ts-sdk** | 忠诚度积分 |
| 状态管理 | **Zustand** | 轻量级状态管理 |
| 部署 | **Vercel** | 快速部署 |

### 4.2 核心 API 集成

#### Tapestry API (https://api.usetapestry.dev/api/v1)
```
POST /profiles/findOrCreate       — 创建/查找用户画像
GET  /profiles/{id}               — 获取画像详情
POST /followers/add               — 关注
POST /followers/remove            — 取关
GET  /profiles/{id}/followers     — 获取粉丝列表
GET  /profiles/{id}/following     — 获取关注列表
GET  /profiles/{id}/suggested-profiles — 推荐好友
POST /contents/findOrCreate       — 创建内容节点
GET  /activity/feed               — 获取动态 Feed
GET  /search/profiles             — 搜索用户
PATCH /profiles/{id}/wallets      — 绑定钱包
```

#### Audius API (https://api.audius.co/v1)
```
GET  /tracks/trending             — 热门曲目
GET  /tracks/search?query=xxx     — 搜索音乐
GET  /tracks/{track_id}           — 曲目详情
GET  /tracks/{track_id}/stream    — 获取流媒体 MP3
GET  /users/search?query=xxx      — 搜索艺术家
GET  /playlists/trending          — 热门歌单
```

### 4.3 身份绑定方案

```
1. 用户用 Nostr 密钥登录（NIP-07 浏览器扩展 或 nsec 导入）
2. 连接 Solana 钱包（Phantom / Backpack）
3. 签名互证：
   - Nostr 私钥签名 Solana 地址
   - Solana 钱包签名 Nostr pubkey
4. 将绑定写入 Tapestry:
   POST /profiles/findOrCreate {
     username: npub...,
     walletAddress: SOL_ADDRESS,
     blockchain: "SOLANA",
     customProperties: { nostrPubkey: "..." }
   }
5. 其他用户可通过 Tapestry 查到 npub ↔ SOL 地址
```

> 💡 **关键洞察：Nostr 和 Solana 都用 ed25519！** 理论上同一个密钥可以同时控制两套系统。

### 4.4 核心数据流

```
用户操作                Nostr Relay              Solana 生态
────────               ──────────               ──────────

发帖 ─────────────────► kind:1 Event ───┐
                                        ├──► Tapestry Content Node
关注好友 ──────────────► kind:3 Event ───┤
                                        ├──► Tapestry Follow Edge
SOL 转账 ─────────────► kind:9735 ──────┤
                                        └──► Solana SPL Transfer TX

分享音乐 ─────────────► kind:1 + tag ──► Audius Track Embed
购买门票 ─────────────► kind:自定义 ────► KYD Protocol TX
领取奖励 ──────────────────────────────► Torque Campaign

收到消息 ◄────────────── kind:4/17 Event
Feed 刷新 ◄──────────── REQ subscription + Tapestry API
```

---

## 五、MVP 范围（10 天可交付）

### P0 — 必须完成（Day 1-6）
- [ ] Next.js 项目初始化 + Tailwind + shadcn/ui
- [ ] Nostr 登录（NIP-07 / nsec）+ Solana 钱包连接（Phantom）
- [ ] 身份绑定 → Tapestry Profile（nostrPubkey ↔ solanaAddress）
- [ ] Nostr 消息 Feed（发帖 + 浏览 kind:1 events）
- [ ] Tapestry 关注/取关 + 粉丝/关注列表
- [ ] Tapestry 好友推荐（suggested profiles）
- [ ] SOL 余额展示 + 给好友转 SOL
- [ ] Audius 音乐搜索 + 聊天中嵌入播放器
- [ ] 移动端友好 UI（底部导航栏: 聊天/动态/发现/钱包/我的）

### P1 — 加分项（Day 7-8）
- [ ] Nostr 1v1 加密私信（NIP-04）
- [ ] SOL 红包（群聊抢红包 + 私聊红包）
- [ ] Audius 热门推荐 Feed + 流媒体播放控制
- [ ] KYD 活动列表浏览
- [ ] Torque 签到积分
- [ ] 聊天内收付款二维码
- [ ] Tapestry 社交图谱可视化

### P2 — 未来展望（Demo 视频中提及）
- [ ] NFT 门票 + 活动群聊
- [ ] DRiP NFT 空投到群
- [ ] Token-gated 频道（持 SPL Token 才能进群）
- [ ] SOL 激励 Nostr Relay
- [ ] Cashu ↔ SOL 互兑

---

## 六、项目结构

```
graveyard-hack/
├── PRD.md
├── package.json
├── next.config.ts
├── tailwind.config.ts
├── tsconfig.json
├── .env.local                    # API keys (Tapestry, Audius)
├── public/
│   └── assets/
├── src/
│   ├── app/                      # Next.js App Router
│   │   ├── layout.tsx            # Root layout + providers
│   │   ├── page.tsx              # Landing / Login
│   │   ├── (main)/               # 登录后主界面
│   │   │   ├── layout.tsx        # 底部导航栏 layout
│   │   │   ├── feed/             # 社交动态 Feed
│   │   │   │   └── page.tsx
│   │   │   ├── chat/             # 消息聊天
│   │   │   │   ├── page.tsx      # 聊天列表
│   │   │   │   └── [pubkey]/     # 1v1 聊天
│   │   │   │       └── page.tsx
│   │   │   ├── discover/         # 发现（音乐/活动/好友）
│   │   │   │   └── page.tsx
│   │   │   ├── wallet/           # 钱包/支付
│   │   │   │   └── page.tsx
│   │   │   └── profile/          # 个人主页
│   │   │       ├── page.tsx
│   │   │       └── [id]/
│   │   │           └── page.tsx
│   │   └── api/                  # API Routes (proxy)
│   │       ├── tapestry/
│   │       └── audius/
│   ├── components/
│   │   ├── ui/                   # shadcn/ui 组件
│   │   ├── nostr/                # Nostr 组件
│   │   │   ├── LoginButton.tsx
│   │   │   ├── PostComposer.tsx
│   │   │   └── FeedItem.tsx
│   │   ├── solana/               # Solana 组件
│   │   │   ├── WalletButton.tsx
│   │   │   ├── TransferDialog.tsx
│   │   │   ├── BalanceDisplay.tsx
│   │   │   └── RedPacket.tsx
│   │   ├── tapestry/             # Tapestry 组件
│   │   │   ├── FollowButton.tsx
│   │   │   ├── FriendList.tsx
│   │   │   ├── SuggestedFriends.tsx
│   │   │   └── SocialGraph.tsx
│   │   ├── audius/               # Audius 组件
│   │   │   ├── TrackCard.tsx
│   │   │   ├── MusicPlayer.tsx
│   │   │   ├── SearchMusic.tsx
│   │   │   └── TrendingTracks.tsx
│   │   └── layout/
│   │       ├── BottomNav.tsx
│   │       ├── Header.tsx
│   │       └── MobileLayout.tsx
│   ├── lib/                      # 核心库
│   │   ├── nostr/
│   │   │   ├── client.ts         # Relay 连接管理
│   │   │   ├── events.ts         # 事件创建/解析
│   │   │   └── keys.ts           # 密钥管理
│   │   ├── solana/
│   │   │   ├── wallet.ts         # 钱包工具
│   │   │   └── transfer.ts       # 转账逻辑
│   │   ├── tapestry/
│   │   │   ├── client.ts         # SocialFi SDK 封装
│   │   │   ├── profile.ts        # 用户画像 CRUD
│   │   │   └── social.ts         # 关注/Feed/推荐
│   │   ├── audius/
│   │   │   ├── client.ts         # Audius API 封装
│   │   │   ├── tracks.ts         # 曲目搜索/播放
│   │   │   └── stream.ts         # 流媒体 URL
│   │   └── kyd/
│   │       └── client.ts         # KYD API 封装
│   ├── hooks/
│   │   ├── useNostr.ts
│   │   ├── useTapestry.ts
│   │   ├── useAudius.ts
│   │   └── useWallet.ts
│   ├── store/
│   │   ├── nostr.ts              # Nostr 状态
│   │   ├── wallet.ts             # 钱包状态
│   │   ├── social.ts             # 社交状态
│   │   └── music.ts              # 音乐播放状态
│   └── types/
│       ├── nostr.ts
│       ├── tapestry.ts
│       └── audius.ts
└── README.md
```

---

## 七、开发里程碑（10 天倒排）

```
Day 1   (2/17)  ── 项目初始化 + 基础 UI 框架 + 路由搭建
Day 2   (2/18)  ── Nostr 登录 + Solana 钱包连接 + 身份绑定 (Tapestry)
Day 3   (2/19)  ── Nostr Feed（发帖/浏览）+ Tapestry 关注/好友
Day 4   (2/20)  ── SOL 钱包余额 + 转账功能 + 聊天基础
Day 5   (2/21)  ── Audius 音乐搜索 + 播放器嵌入
Day 6   (2/22)  ── Tapestry 推荐好友 + 社交图谱 + 动态 Feed
Day 7   (2/23)  ── SOL 红包 + 聊天内支付 UI
Day 8   (2/24)  ── KYD 票务集成 + Torque 积分（如时间允许）
Day 9   (2/25)  ── 联调 + Bug 修复 + UI 打磨 + 移动端适配
Day 10  (2/26-27)  ── 录制 Demo 视频 (≤3min) + README + 提交
```

---

## 八、提交清单

| Hackathon 要求 | 我们的方案 |
|---------------|-----------|
| 基于 Solana 构建 | ✅ Tapestry (Solana) + SOL 转账 + Solana 钱包 |
| 可运行的演示 | ✅ Vercel 部署的 Web App（移动端友好） |
| 视频演示（≤3分钟） | ✅ 录制完整 Demo 流程 |
| GitHub 仓库 | ✅ 本仓库 |
| 团队 1-5 人 | ✅ |

---

## 九、竞争优势 & 评审亮点

1. **一个项目横扫 5 个赛道** — Tapestry + KYD + Audius + Torque + DRiP，最大化中奖概率
2. **真正的「Web3 微信」叙事** — 消息 + 社交 + 支付 + 音乐 + 活动 = 超级客户端
3. **Nostr × Solana 首创融合** — Nostr 抗审查消息 + Solana Tapestry 链上图谱
4. **Audius 音乐体验** — Demo 里播放音乐，评审印象深刻
5. **ed25519 密钥复用** — 一个密钥控制 Nostr + Solana（技术亮点）
6. **跨生态互通** — Tapestry 天然聚合 Farcaster、Lens、Bluesky 用户
7. **基于 0xchat 设计理念** — 致敬开源社区，非闭门造车

---

## 十、参考资源

- **Tapestry:**
  - 文档: https://docs.usetapestry.dev/
  - API Swagger: https://api.usetapestry.dev/docs
  - SDK (npm): socialfi
  - GitHub 模板: https://github.com/Primitives-xyz/tapestry-template
  - API Key 申请: https://app.usetapestry.dev/
  
- **Audius:**
  - API 文档: https://docs.audius.org/api
  - SDK: https://docs.audius.org/sdk
  - Base URL: https://api.audius.co/v1
  - Swagger: https://api.audius.co/v1/swagger.yaml
  
- **KYD Labs:** https://kydlabs.com
- **Torque:** https://docs.torque.so, SDK: @torque-labs/torque-ts-sdk
- **DRiP:** https://drip.haus

- **0xchat (设计灵感):**
  - 主应用: https://github.com/0xchat-app/0xchat-app-main
  - 核心库: https://github.com/0xchat-app/0xchat-core

- **Nostr:**
  - 协议: https://github.com/nostr-protocol/nostr
  - nostr-tools: https://github.com/nbd-wtf/nostr-tools

- **Solana:**
  - Web3.js: https://solana-labs.github.io/solana-web3.js/
  - Wallet Adapter: https://github.com/solana-labs/wallet-adapter
  
- **Hackathon:**
  - 主页: https://solana.com/zh/graveyard-hack
  - 注册: https://solanafoundation.typeform.com/graveyard-hack
