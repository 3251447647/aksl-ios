#!/bin/bash
# Linux/macOS 用 zsign 给未签名 IPA 签名（自签或企业签）
# 用法：bash scripts/sign_ipa.sh AKChat-unsigned.ipa cert.p12 p12密码 profile.mobileprovision
# 依赖：zsign（https://github.com/zhlynn/zsign，macOS 可 brew install zsign）
set -euo pipefail

IPA="${1:-AKChat-unsigned.ipa}"
P12="${2:?需要 .p12 证书}"
PASS="${3:-}"
PROFILE="${4:?需要 .mobileprovision}"

OUT="AKChat-signed.ipa"
zsign -k "$P12" -p "$PASS" -m "$PROFILE" -o "$OUT" "$IPA"

echo "OK: $OUT"
echo "安装后在 iPhone 上信任证书："
echo "  设置 → 通用 → VPN 与设备管理 → 信任对应描述文件"
echo "  自签（免费 Apple ID）还需：设置 → 隐私与安全性 → 开发者模式 → 打开并重启"
