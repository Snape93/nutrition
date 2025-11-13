# -*- coding: utf-8 -*-
import os
import json
import requests

API_BASE = os.environ.get('API_BASE', 'http://127.0.0.1:5000')


def pretty(obj):
    print(json.dumps(obj, indent=2, ensure_ascii=False))


def test_health():
    r = requests.get(f"{API_BASE}/health", timeout=10)
    r.raise_for_status()
    print("/health:")
    pretty(r.json())


def test_meals(user: str):
    r = requests.post(
        f"{API_BASE}/recommendations/meals",
        json={"user": user},
        timeout=20,
    )
    print("/recommendations/meals:")
    print(r.status_code)
    pretty(r.json())


def test_search(query: str, user: str):
    r = requests.post(
        f"{API_BASE}/recommendations/foods/search",
        json={"query": query, "user": user},
        timeout=20,
    )
    print("/recommendations/foods/search:")
    print(r.status_code)
    pretty(r.json())


if __name__ == "__main__":
    user = os.environ.get('TEST_USER', 'demo')
    test_health()
    test_meals(user)
    test_search("adobo", user)
