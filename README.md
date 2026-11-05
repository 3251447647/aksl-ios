# AK商聊 iOS（SwiftUI）

对照安卓 `app-native` 与网页端重写的 iOS 客户端，接口全部复用线上 `/api/v1`，与网页端同一套会话、消息与卡片结构。

## 在 Mac 上运行

1. 安装 Xcode 16+（App Store），命令行执行 `xcode-select --install`。
2. 安装 XcodeGen：`brew install xcodegen`。
3. 生成工程：`cd ios-app && xcodegen generate && open AKChat.xcodeproj`。
4. 在 Signing & Capabilities 里选择 Apple ID 团队，Bundle ID 改为已注册的（默认 `com.yixin.chat.ios`）。
5. 选模拟器或真机运行。

## 目录

- `AKChat/App`：入口与根视图
- `AKChat/Core`：主题、模型、API、WebSocket、登录态、卡片与扩展接口
- `AKChat/Features`：Auth / Main / Home / Chat / Contacts / Me / Moments / Notices

## 已对接

### 账号
- 登录 `POST /api/v1/auth/login`、注册 `POST /api/v1/auth/register`（含邮箱验证码、邀请码）
- 找回密码 `POST /api/v1/auth/email_code` + `/auth/reset_password`
- 隐私开关 `GET /privacy`、`POST /privacy/set`；修改登录/支付密码 `POST /profile/password`
- 当前用户 `GET /me`、资料修改 `POST /profile/update`、注销 `POST /account/delete`

### 会话与消息
- 会话列表、置顶/免打扰/删除/清空、全部已读
- 历史分页（`before_id`）、已读 `POST /read`
- 文本（含 `at_uids`）、图片、语音、表情、撤回、举报
- 发送状态：本地先行显示，失败可点击重试
- 实时通道 `wss://www.aksliao.cn/ws`：message / recall / typing / read / group_top / group_notice 事件

### 聊天卡片（与网页端 extra 结构一致）
- 系统消息（居中、不可点）、充值申请、红包、转账、礼物
- 名片、群名片、通话记录、视频、文件、位置、动态分享、聊天记录
- 时间分隔（5 分钟/跨天）、群主与管理员标签、会员与靓号徽章、@我 标记

### 聊天辅助
- 置顶条（私聊 `/pin`、群 `/group/top`），点击跳回原消息
- 正在输入（`/typing` + WS typing）、@ 成员选择、群公告弹窗与确认
- 长按菜单：复制、收藏、置顶、添加到表情、撤回、举报；图片全屏预览与缩放

### 通讯录与群
- 好友、群聊、好友申请、群邀请
- 用户主页 `/user`：备注、拉黑/取消、删除好友、发消息
- 群资料、成员管理（禁言/踢人/管理员）、公告发布与已读
- 群文件/相册接口已就绪（页面后续接）

### 社交与其它
- 朋友圈：列表、发布、点赞、评论、删除自己的动态、互动消息
- 搜索：用户、群聊（可申请加入）、聊天记录
- 收藏列表与删除（`/favorites`）
- 钱包（余额、账单）、会员套餐展示、靓号购买（`/pretty/*`）
- 公告列表与详情、黑名单、设置、关于与客服

## 待补

- 直播（LiveKit iOS SDK、观众/主播、连麦、评论轮询）、1对1 通话与群通话（CallKit + VoIP push）
- 内购（StoreKit 2 + 服务端验单）、钱包充值/提现
- APNs 服务端发送与推送深链
- 深色模式、字体大小、聊天背景、骨架屏
- 转发选择器、朋友圈详情页与评论回复
- App Store 素材、TestFlight 与 CI

## 注意

- 统一的北京时间（`Asia/Shanghai`），不跟设备时区。
- 代码尚未在 Xcode 编译过（当前环境无 macOS），首次编译重点看泛型解码与并发标注。
