#!/bin/bash

# 下载 Sparkle 工具
if [ ! -f "bin/generate_keys" ]; then
    echo "下载 Sparkle 工具..."
    mkdir -p bin
    curl -L -o sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-for-Swift-Package-Manager.tar.xz
    tar -xf sparkle.tar.xz
    cp bin/generate_keys bin/
    cp bin/sign_update bin/
    rm -rf sparkle.tar.xz
fi

# 生成密钥对
echo "生成 EdDSA 密钥对..."
./bin/generate_keys

echo "请将生成的公钥添加到 Info.plist 的 SUPublicEDKey 中"
echo "私钥请安全保存，用于签名更新包"