# 0xchat-Solana — 产品 & 开发完整规划

> **一句话：** Fork 0xchat（30 万行 Nostr 客户端），加 Solana 链上模块，做 Web3 版微信。
> **护城河：** 隐私碾压 Telegram/WhatsApp + 链上支付/社交/DeFi 一体化。

---

## 一、为什么做这个产品

### 1.1 核心命题

Telegram 有 10 亿用户，WhatsApp 有 20 亿用户。但它们有一个根本性问题：**用户不拥有自己的数据、身份和社交关系**。

我们要做的是：**一个用户真正拥有一切的超级应用**。

| 层级 | 微信/Telegram | 0xchat-Solana |
|------|--------------|---------------|
| 消息通信 | 私有服务器（公司可读） | **Nostr Relay**（去中心化、抗审查） |
| 社交关系 | 平台私有数据（不可迁移） | **Tapestry 链上社交图谱**（公开可组合） |
| 支付 | 微信支付/TON（受管制） | **SOL/SPL Token**（全球无许可） |
| 音乐 | QQ 音乐/Spotify（平台抽成） | **Audius**（创作者直接分成） |
| 活动/服务 | 小程序（平台审批） | **KYD 票务 + 链上服务**（无许可） |
| 积分/奖励 | 积分（不可转让） | **Torque Token 奖励**（可交易） |
| 身份 | 手机号（被监控） | **Nostr 公钥 + Solana 钱包**（自主） |

### 1.2 隐私 — 我们的核心护城河

这是 0xchat-Solana 最大的差异化优势。基于 2026 年最新标准的真实对比：

| 维度 | Nostr (0xchat-Solana) | Telegram | WhatsApp | 谁赢？ |
|------|----------------------|----------|----------|--------|
| **端到端加密 (E2EE)** | 默认全 E2EE（NIP-04/44 DM，NIP-101 优化，MLS 群加密） | 仅 Secret Chats（手动开启），普通聊天/群无 E2EE | 默认全 E2EE（所有聊天/通话），备份可选加密 | **Nostr ≈ WhatsApp >> Telegram** |
| **元数据保护** | 极强：无中央服务器，relay 分布式，pubkey 匿名，无手机号 | 中等：服务器收集 IP、联系人、时间戳 | 弱：Meta 收集大量元数据用于广告 | **Nostr >> Telegram > WhatsApp** |
| **数据存储/控制** | 用户完全拥有数据，无中央存储，可自选 relay | 云存储方便但 Telegram 可访问普通聊天 | 云备份可选加密，Meta 可访问元数据 | **Nostr >> Telegram ≈ WhatsApp** |
| **抗审查/去中心化** | 最高：relay 网络，任意 relay 可跑，无单点失败 | 中等：可封禁频道/用户 | 低：Meta 可封禁账号 | **Nostr >> Telegram > WhatsApp** |
| **手机号绑定** | 无需（纯密钥登录） | 必须手机号 | 必须手机号 | **Nostr 完胜** |
| **开源透明度** | 完全开源（客户端+协议） | 客户端开源，服务器闭源 | 闭源 | **Nostr >> Telegram > WhatsApp** |
| **总体隐私评分** | **90-95/100** | 60-70/100 | 75-80/100 | **Nostr 胜出** |

**结论：** 我们在真实隐私上全面碾压 Telegram 和 WhatsApp。Telegram 的"隐私"更多是营销（普通聊天根本不加密），WhatsApp 被 Meta 元数据收集拖累。Nostr 的无中心、无手机号、无元数据泄露是杀手级优势。

---

## 二、技术战略

### 2.1 核心决策：Fork 0xchat + 加 Solana 模块

站在 30 万行代码之上，只写增量。

```
0xchat 已有的（免费获得）              我们要加的（~3000-5000 行 Dart）
─────────────────────────              ─────────────────────────────
✅ 1v1 明文/加密私信 (NIP-04/17/44)   📦 ox_solana — Solana 钱包模块
✅ 群聊频道 (NIP-28)                     ├── ed25519 密钥管理
✅ Relay 群组 (NIP-29)                   ├── SOL/SPL Token 余额/转账
✅ MLS 加密群聊                          ├── Jupiter DEX Swap
✅ 音视频通话 (NIP-100/WebRTC)           ├── 接收/二维码
✅ Cashu ecash 钱包                      └── Tapestry 身份绑定
✅ Lightning Zap (NIP-57)
✅ 社交 Feed (kind:1)              📦 ox_tapestry — 社交图谱模块
✅ 点赞/Reaction (NIP-25)              ├── Tapestry REST API 封装
✅ 用户 Profile (kind:0)               ├── Follow/Unfollow
✅ 联系人列表 (NIP-02)                  ├── 推荐好友
✅ 多 Relay 管理 (NIP-65)              └── 社交 Feed
✅ Tor 隐私支持
✅ 推送通知                        📦 未来模块
✅ 完整 UI / 主题 / 多语言            ├── ox_audius — 音乐
                                       ├── ox_sui — Sui 钱包
                                       ├── ox_evm — EVM 钱包
                                       └── ox_ai — AI Agent
```

### 2.2 已确认的技术事实

| 项目 | 详情 |
|------|------|
| 0xchat License | MIT（可商用、可修改） |
| 0xchat-app-main | 212,457 行 Dart，8 个业务模块 + 6 个基础框架 |
| 0xchat-core | 78,656 行 Dart，Nostr 核心协议实现 |
| 模块注册机制 | 继承 `OXFlutterModule`，在 `app_initializer.dart` 调用 `.setup()` |
| 模块间通信 | `ox_common/business_interface/` 定义接口，`OXModuleService.invoke()` 调用 |
| Git 子模块 | 4 个：0xchat-core, nostr-dart, cashu-dart, nostr-mls-package |
| Nostr 密钥 | secp256k1 + Schnorr (BIP-340)，和 Bitcoin 相同 |
| Solana 密钥 | ed25519（不同曲线，不能与 Nostr 共用） |
| Dart Solana SDK | `solana` 0.32.0（by Espresso Cash 团队，301⭐，生产级） |
| Jupiter Dart | `jupiter_aggregator`（Espresso Cash 出品，支持 v6 API） |
| Xcode | 已安装 16.4 ✅ |
| Flutter | 未安装 ❌ 需要安装 |

### 2.3 0xchat 模块架构详解

```
0xchat-app-main/
├── lib/
│   ├── main.dart                    # App 入口
│   └── app_initializer.dart         # 模块注册中心 ← 我们改这里
│
├── packages/
│   ├── 0xchat-core/                 # Nostr 核心 (git submodule)
│   ├── nostr-dart/                  # Nostr 底层协议 (git submodule)
│   ├── cashu-dart/                  # eCash 钱包 (git submodule)
│   ├── nostr-mls-package/           # MLS 加密 (git submodule)
│   │
│   ├── base_framework/              # 基础框架
│   │   ├── ox_common/               # 公共工具/接口定义 (69K 行)
│   │   ├── ox_module_service/       # 模块注册/调用机制
│   │   ├── ox_theme/                # 主题系统
│   │   ├── ox_localizable/          # 多语言
│   │   ├── ox_network/              # 网络层
│   │   ├── ox_push/                 # 推送通知
│   │   └── ox_cache_manager/        # 缓存管理
│   │
│   └── business_modules/            # 业务模块
│       ├── ox_chat/                 # 聊天核心 (58K 行, 158 文件)
│       ├── ox_chat_ui/              # 聊天 UI (19K 行, 133 文件)
│       ├── ox_calling/              # 音视频通话 (2.5K 行)
│       ├── ox_discovery/            # 发现/Feed (16K 行)
│       ├── ox_home/                 # 首页 (1.6K 行)
│       ├── ox_login/                # 登录 (1.7K 行)
│       ├── ox_usercenter/           # 用户中心 (17K 行)
│       ├── ox_wallet/               # Cashu 钱包 (6.5K 行)
│       │
│       ├── ox_solana/               # ← 新增：Solana 钱包
│       └── ox_tapestry/             # ← 新增：Tapestry 社交图谱
```

模块注册方式（`app_initializer.dart`）：

```dart
Future<void> _setupModules() async {
  await Future.wait([
    OXCommon().setup(),
    OXLogin().setup(),
    OXUserCenter().setup(),
    OXPush().setup(),
    OXDiscovery().setup(),
    OXChat().setup(),
    OXChatUI().setup(),
    OxCalling().setup(),
    OxChatHome().setup(),
    OXWallet().setup(),
    // ↓ 我们加的
    OXSolana().setup(),       // Solana 钱包
    OXTapestry().setup(),     // Tapestry 社交图谱
  ]);
}
```

### 2.4 需要修改的已有文件（最小改动）

| 文件 | 改动量 | 具体改什么 |
|------|--------|-----------|
| `pubspec.yaml` | +2 行 | 加 `ox_solana` 和 `ox_tapestry` 路径 |
| `lib/app_initializer.dart` | +2 行 | 注册两个新模块 |
| `ox_common/business_interface/` | +2 文件 | `ox_solana/interface.dart` + `ox_tapestry/interface.dart` |
| `ox_home` | ~20 行 | 底部 Tab 加 Solana 钱包入口 |

**总改动：已有代码 < 30 行。** 0xchat 的所有聊天功能完全不用动。

---

## 三、ox_solana 模块设计

### 3.1 文件结构

```
packages/business_modules/ox_solana/
├── pubspec.yaml
├── lib/
│   ├── ox_solana.dart                 # 模块入口 (extends OXFlutterModule)
│   ├── page/
│   │   ├── solana_wallet_page.dart    # 钱包主页（余额+Token列表+操作）
│   │   ├── send_sol_page.dart         # 发送 SOL/SPL Token
│   │   ├── receive_page.dart          # 接收（QR 码展示）
│   │   ├── token_list_page.dart       # SPL Token 列表
│   │   └── swap_page.dart             # Jupiter Swap
│   ├── services/
│   │   ├── solana_wallet_service.dart  # ed25519 密钥生成/导入/存储
│   │   ├── solana_rpc_service.dart     # Solana RPC 封装
│   │   └── jupiter_service.dart        # Jupiter 报价+交换
│   └── widget/
│       ├── balance_card.dart           # 余额卡片 Widget
│       └── token_item.dart             # Token 列表项 Widget
└── assets/
    ├── images/
    └── locale/
```

### 3.2 核心代码框架

**pubspec.yaml:**
```yaml
name: ox_solana
description: Solana wallet module for 0xchat
environment:
  sdk: '>=3.0.5 <4.0.0'
  flutter: ">=1.17.0"
dependencies:
  flutter:
    sdk: flutter
  ox_module_service:
    path: ../../base_framework/ox_module_service/
  ox_common:
    path: ../../base_framework/ox_common
  solana: ^0.32.0                      # Espresso Cash 的 Solana SDK
  jupiter_aggregator:                  # Jupiter DEX
    git:
      url: https://github.com/brij-digital/espresso-cash-public.git
      path: packages/jupiter_aggregator
  qr_flutter: ^4.1.0                  # QR 码生成
  mobile_scanner: ^6.0.11             # QR 码扫描
```

**模块入口 ox_solana.dart:**
```dart
class OXSolana extends OXFlutterModule {
  @override
  String get moduleName => 'ox_solana';

  @override
  Future<void> setup() async {
    await super.setup();
    await SolanaWalletService.instance.init();
  }

  @override
  Future<T?>? navigateToPage<T>(
    BuildContext context, String pageName, Map<String, dynamic>? params) {
    switch (pageName) {
      case 'SolanaWalletPage':
        return OXNavigator.pushPage(context, (ctx) => const SolanaWalletPage());
      case 'SendSolPage':
        return OXNavigator.pushPage(context, (ctx) => SendSolPage(
          recipientAddress: params?['address'] ?? '',
        ));
    }
    return null;
  }

  @override
  Map<String, Function> get interfaces => {
    'getSolanaAddress': () => SolanaWalletService.instance.address,
    'getSolBalance': () => SolanaWalletService.instance.balance,
    'hasSolanaWallet': () => SolanaWalletService.instance.hasWallet,
  };
}
```

**钱包服务 solana_wallet_service.dart:**
```dart
class SolanaWalletService {
  static final instance = SolanaWalletService._();
  SolanaWalletService._();

  Ed25519HDKeyPair? _keyPair;
  SolanaClient? _client;
  String get address => _keyPair?.address ?? '';
  bool get hasWallet => _keyPair != null;
  double balance = 0;

  Future<void> init() async {
    _client = SolanaClient(
      rpcUrl: Uri.parse('https://api.mainnet-beta.solana.com'),
      websocketUrl: Uri.parse('wss://api.mainnet-beta.solana.com'),
    );
  }

  Future<void> createWallet() async {
    _keyPair = await Ed25519HDKeyPair.random();
  }

  Future<void> importFromMnemonic(String mnemonic) async {
    _keyPair = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
  }

  Future<double> getBalance() async {
    if (_keyPair == null || _client == null) return 0;
    final lamports = await _client!.rpcClient.getBalance(address);
    balance = lamports.value / 1e9;
    return balance;
  }

  Future<String> sendSol({
    required String toAddress, required double amount,
  }) async {
    if (_keyPair == null || _client == null) throw Exception('No wallet');
    return await _client!.transferLamports(
      source: _keyPair!,
      destination: Ed25519HDPublicKey.fromBase58(toAddress),
      lamports: (amount * 1e9).toInt(),
    );
  }
}
```

### 3.3 密钥绑定方案（Nostr ↔ Solana）

Nostr 用 secp256k1，Solana 用 ed25519 — **不同曲线，不能共用密钥**。

绑定流程：

```
用户登录 0xchat (已有 Nostr secp256k1 密钥)
    │
    ▼
首次打开 Solana 钱包 Tab
    │
    ├── 方式 1: "生成新 Solana 钱包" → App 内生成 ed25519 密钥对
    ├── 方式 2: "导入已有钱包" → 输入助记词/私钥
    └── 方式 3: "连接外部钱包" → Phantom Deep Link (Phase 2)
    │
    ▼
自动绑定到 Tapestry 链上社交图谱
    POST /profiles/findOrCreate
    {
      "walletAddress": "<solana_base58_address>",
      "properties": {
        "nostrPubkey": "<hex_pubkey>",
        "nostrNpub": "<npub...>"
      }
    }
    │
    ▼
其他用户在聊天中看到你 → 查到你的 Solana 地址 → 直接转账/红包
```

---

## 四、增长策略 — 如何解决拉新难题

### 4.1 Nostr 生态现状（2026）

Nostr 总用户声称 1600 万+，DAU 约 78 万，以 Bitcoin 社区为主。客户端 Damus/Amethyst/Primal 活跃，但整体仍小众。

**增长停滞的真实原因：**

| 原因 | 详情 |
|------|------|
| **冷启动难题** | 没人用 → 没内容 → 没人来。Telegram 靠手机号导入联系人瞬间拉新，Nostr 要手动找 pubkey |
| **UX 摩擦** | 密钥管理复杂（nsec 丢失 = 永久丢失），多端同步不如 Telegram 云同步丝滑 |
| **内容稀缺** | 早期用户多 crypto/Bitcoin 极客，普通人觉得"空洞" |
| **推广资源少** | 无大厂背书、无广告预算、无"你的朋友在用"的病毒式增长 |
| **竞争** | Bluesky 3800 万用户（2025 年爆发）、Mastodon 抢去中心化份额 |

### 4.2 我们的增长杠杆

关键洞察：**我们不是做"又一个 Nostr 客户端"，而是做"第一个 Nostr + Solana 超级应用"**。这意味着我们有两个社区可以拉——Nostr 社区 + Solana 社区。

#### 阶段一：种子用户（0 → 5K，前 3 个月）

| 策略 | 执行方式 | 目标 |
|------|---------|------|
| **SOL 红包拉新** | 聊天内发 SOL 红包，新用户领取需注册 → 病毒式增长 | 每个红包平均拉 5-10 人 |
| **Torque 积分激励** | 邀请好友得积分，积分兑 Token/NFT | 推荐链裂变 |
| **Solana 社区运营** | 在 Solana Discord/X/Reddit 发帖，强调"比 Telegram 更隐私 + 链上支付" | 吃 Solana 存量用户 |
| **Nostr 社区互推** | 在 Nostr relay 发帖，联系 Damus/Primal 开发者互推 | 吃 Nostr 存量用户 |
| **Hackathon 曝光** | Graveyard Hackathon 多赛道参赛，拿奖金 + 媒体报道 | 初始品牌认知 |

#### 阶段二：社区增长（5K → 50K，3-6 个月）

| 策略 | 执行方式 |
|------|---------|
| **音乐社交** | Audius 音乐分享到聊天，"一起听歌"功能，吸引音乐爱好者 |
| **活动社交** | KYD 票务集成，"约朋友买票"，活动群聊自动建群 |
| **DRiP NFT 空投** | 群内 NFT 空投活动，持有 NFT 解锁专属频道 |
| **KOL 合作** | 邀请 Solana/Bitcoin KOL 入驻，他们的粉丝跟着来 |
| **Token-gated 群** | 持 SPL Token 才能进群 → 给 Token 项目方提供社区工具 |

#### 阶段三：破圈增长（50K+，6-12 个月）

| 策略 | 执行方式 |
|------|---------|
| **简化 Onboarding** | 一键生成密钥 + 社交恢复（替代 seed phrase），降低门槛 |
| **跨链扩展** | 加 Sui/EVM 钱包 → 覆盖更多链的用户 |
| **AI Agent 集成** | 聊天内 AI 助手（自动转账、DeFi 策略、翻译），差异化功能 |
| **企业/DAO 工具** | DAO 治理投票、多签金库、团队协作 → B2B 增长 |
| **本地化** | 中/日/韩/东南亚多语言，覆盖 Telegram 在亚洲的份额 |

### 4.3 核心增长飞轮

```
                    ┌──────────────┐
                    │  红包 / 空投  │
                    │  (SOL/NFT)   │
                    └──────┬───────┘
                           │ 拉新
                           ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  内容 / 音乐  │◄──│   活跃用户    │──►│  社交关系     │
│  (Audius)    │    │   (留存)     │    │  (Tapestry)  │
└──────────────┘    └──────┬───────┘    └──────────────┘
                           │ 交易
                           ▼
                    ┌──────────────┐
                    │  钱包 / DeFi  │
                    │  (Jupiter)   │
                    └──────────────┘
```

**飞轮逻辑：** 红包拉新 → 用户活跃 → 建立社交关系（Tapestry）→ 分享内容/音乐 → 用钱包交易 → 赚积分（Torque）→ 用积分发红包 → 拉更多人。

---

## 五、竞品对比

### 5.1 Nostr 客户端对比

| 功能 | 0xchat-Solana (我们) | 0xchat 原版 | Damus | Primal | Amethyst |
|------|---------------------|-------------|-------|--------|----------|
| 加密 DM | ✅ (继承) | ✅ | ✅ | ✅ | ✅ |
| MLS 群加密 | ✅ (继承) | ✅ | ❌ | ❌ | ❌ |
| 音视频通话 | ✅ (继承) | ✅ | ❌ | ❌ | ❌ |
| Cashu 钱包 | ✅ (继承) | ✅ | ❌ | ❌ | ✅ |
| **Solana 钱包** | ✅ **独有** | ❌ | ❌ | ❌ | ❌ |
| **链上社交图谱** | ✅ **独有** | ❌ | ❌ | ❌ | ❌ |
| **DEX Swap** | ✅ **独有** | ❌ | ❌ | ❌ | ❌ |
| **音乐集成** | ✅ **独有** | ❌ | ❌ | ❌ | ❌ |
| 平台 | iOS/Android | iOS/Android | iOS | Web | Android |

### 5.2 聊天 App 隐私对比

| 维度 | 我们 (Nostr) | Telegram | WhatsApp | Signal |
|------|-------------|----------|----------|--------|
| 默认 E2EE | ✅ 全部 | ❌ 仅 Secret Chat | ✅ 全部 | ✅ 全部 |
| 元数据保护 | ✅ 无中心 | ❌ 服务器收集 | ❌ Meta 收集 | ⚠️ 有中心服务器 |
| 抗审查 | ✅ relay 网络 | ⚠️ 可封禁 | ❌ Meta 控制 | ⚠️ 依赖中心 |
| 无手机号 | ✅ | ❌ | ❌ | ❌ |
| 数据主权 | ✅ 完全自主 | ❌ 平台拥有 | ❌ 平台拥有 | ⚠️ 有限 |
| **链上支付** | ✅ SOL | ⚠️ TON | ❌ | ❌ |
| **DeFi 集成** | ✅ Jupiter | ❌ | ❌ | ❌ |
| **链上社交** | ✅ Tapestry | ❌ | ❌ | ❌ |

**定位：Signal 级别的隐私 + Telegram 级别的功能 + 链上支付/DeFi = 我们**

---

## 六、开发路线图

### 6.1 短期：Hackathon（10 天）

如果同时参加 Solana Graveyard Hackathon（截止 2/27）：
- 用 Next.js 快速做 Web Demo（Tapestry 模板 + nostr-tools）
- 0xchat Flutter 版作为"长期产品愿景"在 pitch/视频中展示
- 打 5 个赛道：Tapestry($5K) + KYD($5K) + Audius($3K) + DRiP($2.5K) + Torque($1K)
- 理论最大奖金：$31.5K

### 6.2 中期：产品 MVP（6 周）

| 周 | 目标 | 产出 |
|----|------|------|
| **Week 1** | Flutter 安装 + 0xchat 编译通过 + 跑在模拟器 | 能运行的 0xchat |
| **Week 2** | ox_solana 模块骨架 + 密钥生成/导入 | 钱包页面能显示地址 |
| **Week 3** | SOL 余额查询 + 发送/接收 + QR 码 | 基础钱包功能完成 |
| **Week 4** | SPL Token 列表 + Tapestry 身份绑定 | 完整钱包 + 链上社交绑定 |
| **Week 5** | Jupiter Swap + 聊天内转账入口 | DEX + 聊天-钱包联动 |
| **Week 6** | 集成测试 + Bug 修复 + UI 打磨 | 可 Demo 的产品 |

**6 周后你有：一个带完整 Nostr 聊天 + Solana 钱包 + DEX 的移动 App。**

### 6.3 长期：产品完善（Month 3-12）

| 阶段 | 时间 | 功能 |
|------|------|------|
| **Phase 1** | Month 3-4 | SOL 红包（群聊/私聊）、Audius 音乐集成、Torque 积分 |
| **Phase 2** | Month 4-6 | KYD 票务、DRiP NFT 空投、Token-gated 群 |
| **Phase 3** | Month 6-9 | Sui 钱包 (ox_sui)、EVM 钱包 (ox_evm)、跨链转账 |
| **Phase 4** | Month 9-12 | AI Agent（Flutter WebView + JS Runtime）、DAO 工具 |

---

## 七、环境搭建（Day 1 执行手册）

```bash
# 1. 安装 Flutter SDK
brew install --cask flutter

# 2. 验证环境
flutter doctor
# 确保: Flutter SDK ✅, Xcode ✅, Android toolchain ✅ (可选)

# 3. Fork + Clone (包含子模块)
cd ~/dev/graveyard-hack
git clone --recursive https://github.com/0xchat-app/0xchat-app-main.git 0xchat-solana
cd 0xchat-solana

# 4. 初始化子模块 (如果 --recursive 没拉到)
git submodule update --init --recursive

# 5. 安装依赖
flutter pub get

# 6. 编译运行 (iOS 模拟器)
open -a Simulator
flutter run

# 7. 如果编译成功 → 开始创建 ox_solana 模块
```

---

## 八、参考资源

### 项目基础
| 资源 | 链接 |
|------|------|
| 0xchat 主应用 | https://github.com/0xchat-app/0xchat-app-main |
| 0xchat 核心库 | https://github.com/0xchat-app/0xchat-core |
| Espresso Cash (Flutter Solana 钱包) | https://github.com/brij-digital/espresso-cash-public |
| Solana Dart SDK | https://pub.dev/packages/solana |
| Nostr 协议 | https://github.com/nostr-protocol/nostr |

### Solana 生态集成
| 资源 | 链接 |
|------|------|
| Tapestry 文档 | https://docs.usetapestry.dev |
| Tapestry API Swagger | https://api.usetapestry.dev/docs |
| Tapestry SDK (npm) | socialfi |
| Tapestry API Key 申请 | https://app.usetapestry.dev |
| Audius API | https://api.audius.co/v1 |
| Audius 文档 | https://docs.audius.org/api |
| Torque SDK | @torque-labs/torque-ts-sdk |
| Torque 文档 | https://docs.torque.so |
| KYD Labs | https://kydlabs.com |
| DRiP | https://drip.haus |

### Hackathon
| 资源 | 链接 |
|------|------|
| 主页 | https://solana.com/zh/graveyard-hack |
| 注册 | https://solanafoundation.typeform.com/graveyard-hack |
| 时间 | 2026-02-12 ~ 2026-02-27 |
| 奖金 | 总奖 $15K + 赛道 $16.5K = 理论 $31.5K |

---

## 九、风险与应对

| 风险 | 影响 | 应对方案 |
|------|------|---------|
| Flutter 编译失败 / 0xchat 代码太旧 | 高 | 提前 Week 1 全投入环境搭建，如编译不过则找社区 issue |
| Dart Solana SDK 功能不足 | 中 | Espresso Cash 已生产验证，可参考其代码；不足部分直接 RPC 调用 |
| Tapestry API 需要 Key | 低 | 已知申请入口 https://app.usetapestry.dev |
| 拉新困难 | 高 | SOL 红包 + Torque 积分 + Solana 社区运营（见第四章） |
| 0xchat 团队不合作 | 低 | MIT License，无需许可；但主动联系可能获得支持 |
| 竞品抢先 | 中 | 快速迭代，聚焦 Nostr+Solana 这个独特交叉点 |
