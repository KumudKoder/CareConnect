#!/usr/bin/env python3
"""Simple staged-content secret scanner for git pre-commit.

Scans ONLY staged files to prevent accidental commit of credentials.
"""

from __future__ import annotations

import re
import subprocess
import sys
from typing import List

# Common high-signal patterns
PATTERNS = [
    ("Google API key", re.compile(r"AIza[0-9A-Za-z\-_]{20,}")),
    ("OpenAI key", re.compile(r"sk-[A-Za-z0-9]{20,}")),
    ("GitHub PAT", re.compile(r"ghp_[A-Za-z0-9]{20,}")),
    ("Private key block", re.compile(r"BEGIN (?:RSA|EC|OPENSSH|DSA) PRIVATE KEY")),
    ("Generic API assignment", re.compile(r"(?i)(api[_-]?key|token|secret)\s*[:=]\s*['\"][^'\"]{8,}['\"]")),
]

# Allow known safe placeholders
ALLOW_SUBSTRINGS = [
    "YOUR_",
    "dummy",
    "example",
    "<your-",
    "<path-to-",
]


def run_git(args: List[str]) -> str:
    result = subprocess.run(
        ["git", *args],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        return ""
    return result.stdout


def staged_files() -> List[str]:
    out = run_git(["diff", "--cached", "--name-only", "--diff-filter=ACMR"])
    return [line.strip() for line in out.splitlines() if line.strip()]


def staged_content(path: str) -> str:
    # Read content exactly as staged in index
    return run_git(["show", f":{path}"])


def is_likely_placeholder(line: str) -> bool:
    lower = line.lower()
    return any(s.lower() in lower for s in ALLOW_SUBSTRINGS)


def main() -> int:
    files = staged_files()
    if not files:
        return 0

    hits: List[str] = []

    for f in files:
        # Skip binaries-ish files by extension (lightweight)
        if f.lower().endswith((".png", ".jpg", ".jpeg", ".gif", ".pdf", ".apk", ".aab", ".keystore", ".jks")):
            continue

        content = staged_content(f)
        if not content:
            continue

        for i, line in enumerate(content.splitlines(), start=1):
            if is_likely_placeholder(line):
                continue
            for label, pattern in PATTERNS:
                if pattern.search(line):
                    hits.append(f"{f}:{i} [{label}] {line.strip()[:180]}")

    if hits:
        print("\n[secret-scan] Potential secrets detected in staged changes:\n")
        for h in hits:
            print(f" - {h}")
        print("\nCommit blocked. Remove secrets or replace with placeholders before committing.\n")
        return 1

    print("[secret-scan] OK: no high-signal secrets found in staged files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
