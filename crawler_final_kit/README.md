# Crawler Final Kit / 公开数据采集工程库

Crawler Final Kit 是给 OpenClaw 使用的本地公开数据采集工具库。目标是让 OpenClaw 具备稳定、合规、可复用、可交付的数据采集能力。

## 核心定位

让 OpenClaw 成为“公开数据采集工程师”：

- 采集前读取 robots.txt。
- 优先使用公开 API、RSS、Sitemap 和网站导出功能。
- 对公开网页做小规模、低频率采集。
- 提取标题、正文摘要、链接、表格。
- 输出 JSON、CSV、Excel、Markdown 报告。
- 记录日志、失败原因和停止原因。
- 遇到权限限制、频率限制、登录页、异常状态码时停止并报告。

## 安全边界

本库只面向公开、允许访问的数据页面。遇到需要账号权限、验证码、付费权限、隐私内容或网站明确拒绝的情况，必须停止，并写入报告。

## 模块结构

```text
crawler_final_kit/
├─ README.md
├─ requirements.txt
├─ crawler_agent.py
├─ crawler_rules.md
├─ examples/
│  └─ targets.json
└─ output/
```

## 安装

在 openclaw 仓库根目录执行：

```bash
python3 -m pip install --user -r crawler_final_kit/requirements.txt
```

## 快速测试

```bash
python3 crawler_final_kit/crawler_agent.py \
  --config crawler_final_kit/examples/targets.json \
  --out /mnt/c/OpenClawWork/Crawler_Final/output
```

输出位置：

```text
C:\OpenClawWork\Crawler_Final\output
```

## 给 OpenClaw 的调用规则

```text
进入公开数据采集工程模式。

只使用本地 Crawler Final Kit：
/home/bai/OpenClawRepos/openclaw/crawler_final_kit

规则：
1. 只采集公开页面。
2. 采集前读取 robots.txt。
3. 优先使用公开 API、RSS、Sitemap。
4. 每个站点默认最多采集 20 页。
5. 每次请求间隔不少于 2 秒。
6. 遇到 403、429、登录页、验证码页、付费页，立即停止并报告。
7. 输出 JSON、CSV、Excel 和 Markdown 报告。
8. 完成后写学习卡片。
```

## 任务配置格式

```json
{
  "job_name": "public_page_demo",
  "respect_robots": true,
  "delay_seconds": 2,
  "timeout_seconds": 15,
  "max_pages_per_site": 5,
  "targets": [
    {
      "name": "Example",
      "start_url": "https://example.com",
      "allowed_domains": ["example.com"],
      "mode": "single_page"
    }
  ]
}
```

## 输出文件

每次运行会生成：

- `crawl_result.json`
- `crawl_result.csv`
- `crawl_result.xlsx`
- `crawl_report.md`
- `crawl_log.txt`
