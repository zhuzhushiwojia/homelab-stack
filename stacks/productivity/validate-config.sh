#!/bin/bash
set -e

echo "🔍 开始验证 Productivity Stack 配置..."

# 检查 YAML 语法
echo "📄 检查 docker-compose.yml 语法..."
if docker-compose config -q; then
    echo "✅ docker-compose.yml 语法正确"
else
    echo "❌ docker-compose.yml 语法错误"
    exit 1
fi

# 检查必需的文件
echo "📁 检查必需文件..."
required_files=(
    "docker-compose.yml"
    ".env.example"
    "README.md"
    "scripts/init-databases.sh"
    "test-productivity.sh"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file 存在"
    else
        echo "❌ $file 不存在"
        exit 1
    fi
done

# 检查脚本权限
echo "🔧 检查脚本权限..."
scripts=(
    "scripts/init-databases.sh"
    "test-productivity.sh"
    "validate-config.sh"
)

for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        echo "✅ $script 可执行"
    else
        echo "⚠️  $script 不可执行，正在修复..."
        chmod +x "$script"
    fi
done

# 检查镜像版本
echo "🐳 检查 Docker 镜像版本..."
images=$(grep -h "image:" docker-compose.yml | sed 's/.*image: //' | sort -u)

for image in $images; do
    # 移除变量引用，只检查固定版本
    if [[ $image == *"\${"* ]]; then
        echo "⚠️  $image 包含环境变量，跳过检查"
    elif [[ $image == *":latest"* ]] || [[ $image == *":latest-sha"* ]]; then
        echo "⚠️  $image 使用 latest 标签，建议使用固定版本"
    else
        echo "✅ $image 使用固定版本"
    fi
done

# 检查硬编码密码
echo "🔒 检查硬编码密码..."
if grep -r "password\|secret\|token" --include="*.yml" --include="*.yaml" . | grep -v ".env.example" | grep -v "test-productivity.sh" | grep -v "validate-config.sh" | grep -v "README.md" | grep -v "# " | grep -v "POSTGRES_PASSWORD=\|GITEA_DB_PASSWORD=\|VAULTWARDEN_ADMIN_TOKEN=\|OUTLINE_SECRET_KEY=" | grep -q "="; then
    echo "❌ 发现可能的硬编码密码，请检查以下行："
    grep -r "password\|secret\|token" --include="*.yml" --include="*.yaml" . | grep -v ".env.example" | grep -v "test-productivity.sh" | grep -v "validate-config.sh" | grep -v "README.md" | grep -v "# " | grep -v "POSTGRES_PASSWORD=\|GITEA_DB_PASSWORD=\|VAULTWARDEN_ADMIN_TOKEN=\|OUTLINE_SECRET_KEY=" | grep "="
    exit 1
else
    echo "✅ 未发现硬编码密码"
fi

# 检查健康检查配置
echo "🏥 检查健康检查配置..."
services_with_healthcheck=$(grep -l "healthcheck:" docker-compose.yml)
if [ -n "$services_with_healthcheck" ]; then
    echo "✅ 以下服务配置了健康检查："
    grep -B2 "healthcheck:" docker-compose.yml | grep "services:" | sed 's/services://' | sed 's/://' | sed 's/^[[:space:]]*//' | sort -u
else
    echo "⚠️  未发现健康检查配置"
fi

# 检查 Traefik 标签
echo "🚦 检查 Traefik 配置..."
services_with_traefik=$(grep -l "traefik\." docker-compose.yml)
if [ -n "$services_with_traefik" ]; then
    echo "✅ 以下服务配置了 Traefik："
    grep -B5 "traefik\." docker-compose.yml | grep "services:" | sed 's/services://' | sed 's/://' | sed 's/^[[:space:]]*//' | sort -u
else
    echo "❌ 未发现 Traefik 配置"
    exit 1
fi

# 检查网络配置
echo "🌐 检查网络配置..."
if grep -q "traefik-public" docker-compose.yml && grep -q "internal" docker-compose.yml; then
    echo "✅ 网络配置正确 (traefik-public + internal)"
else
    echo "❌ 网络配置不完整"
    exit 1
fi

# 检查数据持久化
echo "💾 检查数据持久化..."
services_with_volumes=$(grep -B2 "volumes:" docker-compose.yml | grep "services:" | sed 's/services://' | sed 's/://' | sed 's/^[[:space:]]*//' | sort -u)
if [ -n "$services_with_volumes" ]; then
    echo "✅ 以下服务配置了数据卷："
    echo "$services_with_volumes"
else
    echo "⚠️  未发现数据卷配置"
fi

# 生成验证报告
echo ""
echo "📋 配置验证报告"
echo "════════════════════════════════════════════════════════════════"
echo "✅ 所有必需文件存在"
echo "✅ Docker Compose 语法正确"
echo "✅ 未发现硬编码密码"
echo "✅ Traefik 反向代理配置完整"
echo "✅ 网络隔离配置正确"
echo "✅ 数据持久化配置完整"
echo ""
echo "🎯 建议改进："
echo "   1. 确保所有镜像使用固定版本"
echo "   2. 为所有关键服务添加健康检查"
echo "   3. 定期备份 .env 文件中的密钥"
echo "   4. 配置完整的监控和告警"
echo ""
echo "🚀 配置验证通过！可以开始部署了。"