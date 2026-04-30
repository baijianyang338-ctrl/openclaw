from __future__ import annotations

import argparse
import csv
import json
import re
import time
import urllib.parse
import urllib.robotparser
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List

import pandas as pd
import requests
from bs4 import BeautifulSoup


STOP_PATTERNS = [
    "login",
    "sign in",
    "signin",
    "captcha",
    "verify you are human",
    "access denied",
    "forbidden",
    "too many requests",
    "payment required",
    "subscribe",
]


@dataclass
class CrawlItem:
    target_name: str
    url: str
    status_code: int
    title: str
    summary: str
    links: List[str]
    stop_reason: str = ""


def load_config(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def domain_of(url: str) -> str:
    return urllib.parse.urlparse(url).netloc.lower()


def same_allowed_domain(url: str, allowed: List[str]) -> bool:
    host = domain_of(url)
    return any(host == d.lower() or host.endswith("." + d.lower()) for d in allowed)


def robots_allowed(url: str, user_agent: str = "OpenClawCrawlerFinalKit") -> tuple[bool, str]:
    parsed = urllib.parse.urlparse(url)
    robots_url = f"{parsed.scheme}://{parsed.netloc}/robots.txt"
    rp = urllib.robotparser.RobotFileParser()
    try:
        rp.set_url(robots_url)
        rp.read()
        return rp.can_fetch(user_agent, url), robots_url
    except Exception as exc:
        return True, f"{robots_url} read_failed={exc}"


def looks_restricted(text: str) -> str:
    low = text.lower()[:10000]
    for pat in STOP_PATTERNS:
        if pat in low:
            return f"page_contains_{pat.replace(' ', '_')}"
    return ""


def clean_text(text: str) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    return text


def extract_page(target_name: str, url: str, html: str, status_code: int) -> CrawlItem:
    soup = BeautifulSoup(html, "lxml")
    title = soup.title.get_text(strip=True) if soup.title else ""
    for tag in soup(["script", "style", "noscript"]):
        tag.extract()
    body = clean_text(soup.get_text(" "))
    links = []
    for a in soup.find_all("a", href=True):
        href = urllib.parse.urljoin(url, a.get("href"))
        links.append(href)
    # dedupe while preserving order
    deduped = []
    seen = set()
    for link in links:
        if link not in seen:
            seen.add(link)
            deduped.append(link)
    return CrawlItem(
        target_name=target_name,
        url=url,
        status_code=status_code,
        title=title,
        summary=body[:1000],
        links=deduped[:50],
    )


def fetch_one(session: requests.Session, target: Dict[str, Any], url: str, timeout: int) -> CrawlItem:
    name = target.get("name", "target")
    allowed = target.get("allowed_domains", [])
    if allowed and not same_allowed_domain(url, allowed):
        return CrawlItem(name, url, 0, "", "", [], "domain_not_allowed")

    try:
        resp = session.get(url, timeout=timeout)
    except Exception as exc:
        return CrawlItem(name, url, 0, "", "", [], f"request_error={exc}")

    if resp.status_code in {401, 403, 429}:
        return CrawlItem(name, url, resp.status_code, "", "", [], f"stop_status_{resp.status_code}")
    if resp.status_code >= 500:
        return CrawlItem(name, url, resp.status_code, "", "", [], f"server_error_{resp.status_code}")
    if resp.status_code >= 400:
        return CrawlItem(name, url, resp.status_code, "", "", [], f"client_error_{resp.status_code}")

    text = resp.text
    restricted = looks_restricted(text)
    if restricted:
        return CrawlItem(name, url, resp.status_code, "", "", [], restricted)

    return extract_page(name, url, text, resp.status_code)


def crawl(config: Dict[str, Any], out_dir: Path) -> List[CrawlItem]:
    out_dir.mkdir(parents=True, exist_ok=True)
    log_path = out_dir / "crawl_log.txt"
    delay = float(config.get("delay_seconds", 2))
    timeout = int(config.get("timeout_seconds", 15))
    max_pages = int(config.get("max_pages_per_site", 5))
    respect_robots = bool(config.get("respect_robots", True))

    session = requests.Session()
    session.headers.update({"User-Agent": "OpenClawCrawlerFinalKit/1.0 (+public-data-collection)"})

    results: List[CrawlItem] = []
    with log_path.open("w", encoding="utf-8") as log:
        log.write(f"job={config.get('job_name', 'unnamed')}\n")
        for target in config.get("targets", []):
            name = target.get("name", "target")
            start = target.get("start_url")
            if not start:
                log.write(f"[{name}] missing start_url\n")
                continue

            if respect_robots:
                allowed, robots_info = robots_allowed(start)
                log.write(f"[{name}] robots={robots_info} allowed={allowed}\n")
                if not allowed:
                    results.append(CrawlItem(name, start, 0, "", "", [], "robots_disallow"))
                    continue

            queue = [start]
            seen = set()
            count = 0
            while queue and count < max_pages:
                url = queue.pop(0)
                if url in seen:
                    continue
                seen.add(url)
                log.write(f"[{name}] fetch {url}\n")
                item = fetch_one(session, target, url, timeout)
                results.append(item)
                count += 1
                if item.stop_reason:
                    log.write(f"[{name}] stop_or_skip {url} reason={item.stop_reason}\n")
                    if item.stop_reason.startswith("stop_status") or "restricted" in item.stop_reason:
                        break
                else:
                    mode = target.get("mode", "single_page")
                    if mode == "crawl_links":
                        for link in item.links:
                            if target.get("allowed_domains") and same_allowed_domain(link, target.get("allowed_domains", [])):
                                if link not in seen and len(queue) < max_pages * 3:
                                    queue.append(link)
                time.sleep(delay)
    return results


def save_outputs(results: List[CrawlItem], out_dir: Path, config: Dict[str, Any]) -> None:
    records = [
        {
            "target_name": r.target_name,
            "url": r.url,
            "status_code": r.status_code,
            "title": r.title,
            "summary": r.summary,
            "links_count": len(r.links),
            "stop_reason": r.stop_reason,
        }
        for r in results
    ]
    (out_dir / "crawl_result.json").write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    with (out_dir / "crawl_result.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(records[0].keys()) if records else ["target_name", "url"])
        writer.writeheader()
        writer.writerows(records)
    pd.DataFrame(records).to_excel(out_dir / "crawl_result.xlsx", index=False)

    stops = [r for r in results if r.stop_reason]
    report = [
        "# Crawler Final Kit 采集报告",
        "",
        f"任务：{config.get('job_name', 'unnamed')}",
        f"结果数量：{len(results)}",
        f"停止/跳过数量：{len(stops)}",
        "",
        "## 输出文件",
        "- crawl_result.json",
        "- crawl_result.csv",
        "- crawl_result.xlsx",
        "- crawl_log.txt",
        "",
        "## 停止/跳过原因",
    ]
    if stops:
        for r in stops:
            report.append(f"- {r.url}: {r.stop_reason}")
    else:
        report.append("- 无")
    (out_dir / "crawl_report.md").write_text("\n".join(report), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Crawler Final Kit: public data collection runner.")
    parser.add_argument("--config", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    config = load_config(Path(args.config))
    out_dir = Path(args.out)
    results = crawl(config, out_dir)
    save_outputs(results, out_dir, config)
    print(f"Crawler job finished. Output: {out_dir}")
    print(f"Report: {out_dir / 'crawl_report.md'}")


if __name__ == "__main__":
    main()
