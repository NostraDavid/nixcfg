#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#   "niquests==3.20.1",
# ]
# ///
"""Shared, typed GitHub HTTP helpers for the skill installer commands."""

from __future__ import annotations

import os

import niquests as http

DEFAULT_TIMEOUT_SECONDS = 30.0


class GitHubRequestError(Exception):
    """Report an expected GitHub request failure with an optional status."""

    def __init__(self, message: str, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code


def github_request(
    url: str, user_agent: str, *, timeout: float = DEFAULT_TIMEOUT_SECONDS
) -> bytes:
    """Fetch URL with GitHub authentication and a bounded timeout."""
    headers = {"User-Agent": user_agent}
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        response = http.get(url, headers=headers, timeout=timeout)
    except http.exceptions.RequestException as exc:
        raise GitHubRequestError(f"GitHub request failed: {exc}") from exc
    status_code = response.status_code
    if status_code is None:
        raise GitHubRequestError("GitHub returned no HTTP status")
    if status_code >= 400:
        raise GitHubRequestError(
            f"GitHub request failed with HTTP {status_code}",
            status_code,
        )
    content = response.content
    if content is None:
        raise GitHubRequestError("GitHub returned no response body", status_code)
    return content


def github_api_contents_url(repo: str, path: str, ref: str) -> str:
    """Build a GitHub contents API URL for a repository path."""
    return f"https://api.github.com/repos/{repo}/contents/{path}?ref={ref}"
