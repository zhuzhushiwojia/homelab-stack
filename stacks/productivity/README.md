# 🚀 Productivity Stack - 生产力工具套件

## 📋 项目概述

这是一个完整的自托管生产力工具套件，包含代码托管、密码管理、团队知识库、PDF 处理和在线白板工具。

### 服务清单

| 服务 | 用途 | 访问地址 |
|------|------|----------|
| Gitea | Git 代码托管 | `https://gitea.your-domain.com` |
| Vaultwarden | 密码管理器 (Bitwarden 兼容) | `https://vaultwarden.your-domain.com` |
| Outline | 团队知识库 | `https://outline.your-domain.com` |
| Stirling PDF | PDF 处理工具 | `https://stirling-pdf.your-domain.com` |
| Excalidraw | 在线白板 | `https://excalidraw.your-domain.com` |

## 🛠️ 快速开始

### 1. 环境准备

```bash
# 克隆项目
git clone <repository-url>
cd homelab-productivity

# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件，填写实际配置
nano .env
```

### 2. 生成安全密钥

```bash
# 生成随机密码和密钥
openssl rand -hex 32  # 用于 GITEA_JWT_SECRET
openssl rand -hex 32  # 用于 VAULTWARDEN_ADMIN_TOKEN
openssl rand -hex 32  # 用于 OUTLINE_SECRET_KEY
openssl rand -hex 32  # 用于 OUTLINE_UTILS_SECRET
openssl rand -hex 32  # 用于 POSTGRES_PASSWORD
openssl rand -hex 32  # 用于 GITEA_DB_PASSWORD
openssl rand -hex 32  # 用于 VAULTWARDEN_DB_PASSWORD
openssl rand -hex 32  # 用于 OUTLINE_DB_PASSWORD
openssl rand -hex 32  # 用于 REDIS_PASSWORD
```

### 3. 配置 Authentik OIDC (可选但推荐)

1. 登录 Authentik 管理界面
2. 创建新的 OAuth2/OpenID Provider
3. 为 Outline 创建客户端
4. 获取 `OUTLINE_OIDC_CLIENT_ID` 和 `OUTLINE_OIDC_CLIENT_SECRET`
5. 更新 .env 文件中的对应配置

### 4. 配置 MinIO (Outline 文件存储)

1. 确保 MinIO 服务可用
2. 创建名为 `outline` 的存储桶
3. 获取访问密钥并更新 .env 文件

### 5. 启动服务

```bash
# 启动所有服务
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看服务日志
docker-compose logs -f
```

## 🔧 详细配置

### Gitea 配置

#### 初始设置
1. 访问 `https://gitea.your-domain.com`
2. 使用管理员账号登录
3. 配置 Authentik OIDC (如果启用)
4. 配置 SMTP 邮件通知

#### 重要配置项
- 禁用公开注册 (`GITEA__service__DISABLE_REGISTRATION=true`)
- 配置 SSH 访问端口 (默认: 2222)
- 配置数据库连接

### Vaultwarden 配置

#### 安全注意事项
- **必须** 使用 HTTPS (浏览器扩展要求)
- 禁用公开注册 (`SIGNUPS_ALLOWED=false`)
- 启用邀请系统 (`INVITATIONS_ALLOWED=true`)
- 配置强 `ADMIN_TOKEN`

#### 浏览器扩展配置
1. 安装 Bitwarden 浏览器扩展
2. 设置服务器地址: `https://vaultwarden.your-domain.com`
3. 登录或注册账号

### Outline 配置

#### OIDC 集成
1. 确保 Authentik 配置正确
2. Outline 会自动使用 OIDC 登录
3. 首次登录会自动创建用户

#### 文件存储
- 使用 MinIO 作为 S3 兼容存储
- 配置存储桶和访问密钥
- 支持图片、文档等文件上传

### Stirling PDF 配置

#### 功能特性
- 支持 50+ PDF 处理功能
- OCR 文字识别
- 图片转 PDF
- PDF 合并/拆分/压缩
- 格式转换 (Word/Excel/HTML/Markdown 等)

#### 使用说明
1. 访问 Web 界面
2. 上传 PDF 文件
3. 选择处理功能
4. 下载处理结果

### Excalidraw 配置

#### 功能特性
- 实时协作白板
- 支持导出 PNG/SVG
- 丰富的图形库
- 版本历史

## 📊 健康检查

所有服务都配置了健康检查，可以通过以下方式验证：

```bash
# 检查服务健康状态
docker-compose ps

# 查看详细健康状态
docker inspect --format='{{json .State.Health}}' <container_name>

# 手动测试 HTTP 端点
curl -f https://gitea.your-domain.com/healthz
curl -f https://vaultwarden.your-domain.com/alive
```

## 🔒 安全配置

### 网络隔离
- 内部服务使用 `internal` 网络
- 对外服务通过 Traefik 反向代理
- 数据库仅内部网络可访问

### 数据加密
- 所有服务强制 HTTPS
- 数据库连接使用密码认证
- Redis 配置访问密码

### 访问控制
- Gitea: 禁用公开注册，仅管理员创建账号
- Vaultwarden: 禁用公开注册，仅邀请注册
- Outline: 通过 Authentik OIDC 统一认证

## 🚨 故障排除

### 常见问题

#### 1. 服务无法启动
```bash
# 检查日志
docker-compose logs <service_name>

# 检查端口冲突
netstat -tulpn | grep :<port>

# 检查网络配置
docker network ls
docker network inspect traefik-public
```

#### 2. 数据库连接失败
```bash
# 检查数据库容器状态
docker-compose logs postgres

# 检查数据库初始化
docker exec -it postgres-productivity psql -U postgres -c "\l"

# 检查环境变量
docker-compose config | grep -A5 -B5 "POSTGRES"
```

#### 3. HTTPS 证书问题
```bash
# 检查 Traefik 配置
docker-compose logs traefik

# 检查 Let's Encrypt 证书
docker exec -it traefik cat /etc/traefik/certs/acme.json | jq .
```

#### 4. OIDC 登录失败
1. 检查 Authentik 客户端配置
2. 验证回调 URL 配置
3. 检查 Outline 环境变量
4. 查看 Outline 日志: `docker-compose logs outline`

## 📈 监控和维护

### 备份策略

#### 数据库备份
```bash
# PostgreSQL 备份
docker exec postgres-productivity pg_dumpall -U postgres > backup.sql

# Redis 备份
docker exec redis-productivity redis-cli --pass $REDIS_PASSWORD SAVE
docker cp redis-productivity:/data/dump.rdb ./redis-backup.rdb
```

#### 数据卷备份
```bash
# 备份所有数据卷
docker run --rm -v gitea_data:/source -v $(pwd)/backup:/backup alpine tar czf /backup/gitea_data.tar.gz -C /source .
```

### 更新策略

#### 手动更新
```bash
# 拉取最新镜像
docker-compose pull

# 重启服务
docker-compose up -d

# 清理旧镜像
docker image prune -f
```

#### 自动更新 (通过 Watchtower)
- 所有服务都启用了 Watchtower 标签
- Watchtower 会自动更新到最新版本
- 更新时间为每天凌晨 3 点

## 🔗 相关链接

- [Gitea 文档](https://docs.gitea.io/)
- [Vaultwarden 文档](https://github.com/dani-garcia/vaultwarden/wiki)
- [Outline 文档](https://docs.getoutline.com/)
- [Stirling PDF GitHub](https://github.com/Stirling-Tools/Stirling-PDF)
- [Excalidraw GitHub](https://github.com/excalidraw/excalidraw)

## 📝 许可证

本项目遵循 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

---

**🚀 部署完成！开始享受你的自托管生产力套件吧！**