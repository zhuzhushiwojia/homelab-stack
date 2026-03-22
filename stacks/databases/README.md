# Database Stack - PostgreSQL + Redis + MariaDB

共享数据库层，为所有 Homelab 服务提供统一的数据库服务。

## 服务组成

- **PostgreSQL**: 关系型数据库
- **Redis**: 缓存/会话存储
- **MariaDB**: MySQL 兼容数据库

## 部署说明

```bash
cd stacks/databases
docker compose up -d
```

## Bounty Claim

**Wallet**: USDT TRC20: TMLkvEDrjvHEUbWYU1jfqyUKmbLNZkx6T1

**Status**: ✅ Implementation Complete - Ready for Review
