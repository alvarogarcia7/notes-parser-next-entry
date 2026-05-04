#!/usr/bin/env python3
"""
Demo: HackerNews Data Pipeline
Shows how data transforms from Google Keep note to parsed HackerNews message
(Simplified version without external dependencies)
"""

import json
import uuid
import re
from pathlib import Path

def demo():
    """Demonstrate the HackerNews data pipeline."""

    # Load sample
    sample_file = Path(__file__).parent / "google-keep-notes-parser/sample/hn/1.json"
    with open(sample_file) as f:
        note = json.load(f)

    print("=" * 80)
    print("HACKERNEWS DATA PIPELINE DEMONSTRATION")
    print("=" * 80)

    # =========================================================================
    # STAGE 1: Publisher Input (messages.10.raw.type.googlenotes)
    # =========================================================================
    print("\n📥 STAGE 1: Publisher Input")
    print("-" * 80)
    print("Topic: messages.10.raw.type.googlenotes")
    print("Source: Google Keep Note (sample/hn/1.json)")

    msg_id = str(uuid.uuid4())
    stage1_msg = {
        "id": msg_id,
        "note": note,
        "date": "2026-01-15"
    }

    print("\nMessage sent to messages.10.raw.type.googlenotes:")
    print(json.dumps(stage1_msg, indent=2)[:500] + "...")

    # =========================================================================
    # STAGE 2: Router Detection (messages.10.raw.type.googlenotes)
    # =========================================================================
    print("\n" + "=" * 80)
    print("🔀 STAGE 2: Router Detection")
    print("-" * 80)

    # Check if HackerNews
    hn_pattern = r'https?://news\.ycombinator\.com/item\?id=(\d+)'
    has_hn_label = 'Download-HN' in note.get('labels', [])
    has_hn_url = bool(re.search(hn_pattern, note.get('text', '') + note.get('title', '')))

    print(f"Analyzing note: '{note.get('title', 'Untitled')[:50]}...'")
    print(f"Has 'Download-HN' label: {has_hn_label}")
    print(f"Has HackerNews URL (news.ycombinator.com): {has_hn_url}")

    is_hn = has_hn_label or has_hn_url
    print(f"Detection result: {'✓ HackerNews' if is_hn else '✗ Generic Google Note'}")

    # =========================================================================
    # STAGE 3: Router Output (messages.20.hn)
    # =========================================================================
    print("\n" + "=" * 80)
    print("📤 STAGE 3: Router Output")
    print("-" * 80)
    print("Topic: messages.20.hn")

    stage3_msg = {
        "id": msg_id,
        "message_type": "hackernews",
        "note": {
            "id": note.get("id"),
            "title": note.get("title", "Untitled"),
            "text": note.get("text"),
            "url": note.get("url"),
            "date": "2026-01-15",
        },
        "source": "google-keep"
    }

    print("\nMessage sent to messages.20.hn:")
    print(json.dumps(stage3_msg, indent=2)[:600] + "...")

    # =========================================================================
    # STAGE 4: Parser Extraction (messages.20.hn → messages.30.type.hn.10.parsed)
    # =========================================================================
    print("\n" + "=" * 80)
    print("🔧 STAGE 4: HackerNews Parser")
    print("-" * 80)
    print("Parsing HackerNews data from messages.20.hn...")

    # Extract HN item ID
    text = note.get('text', '')
    match = re.search(hn_pattern, text)
    item_id = match.group(1) if match else "unknown"
    hn_url = match.group(0) if match else ""

    print(f"\n✓ Successfully parsed HackerNews note")
    print(f"  Title: {note.get('title', 'Untitled')[:60]}...")
    print(f"  Item ID: {item_id}")
    print(f"  URL: {hn_url}")
    print(f"  Labels: {', '.join(note.get('labels', []))}")

    # =====================================================================
    # STAGE 5: Final Output (messages.30.type.hn.10.parsed)
    # =====================================================================
    print("\n" + "=" * 80)
    print("✅ STAGE 5: Final Output")
    print("-" * 80)
    print("Topic: messages.30.type.hn.10.parsed")

    stage5_msg = {
        "id": msg_id,
        "message_id": msg_id,
        "note_id": note.get("id"),
        "type": "hackernews",
        "parsed": {
            "title": note.get("title", "Untitled"),
            "item_id": item_id,
            "url": hn_url,
            "description": text,
            "labels": note.get('labels', []),
            "hn_links": [
                {
                    "url": hn_url,
                    "item_id": item_id
                }
            ] if hn_url else []
        },
        "source": "google-keep",
        "date": "2026-01-15"
    }

    print("\nFinal message sent to messages.30.type.hn.10.parsed:")
    print(json.dumps(stage5_msg, indent=2))

    # =====================================================================
    # SUMMARY
    # =====================================================================
    print("\n" + "=" * 80)
    print("📊 PIPELINE SUMMARY")
    print("-" * 80)
    print(f"✓ Input:     Google Keep Note ({note.get('id')})")
    print(f"✓ Stage 1:   messages.10.raw.type.googlenotes")
    print(f"✓ Stage 2:   Router detects HackerNews")
    print(f"✓ Stage 3:   messages.20.hn")
    print(f"✓ Stage 4:   HackerNews Parser extracts data")
    print(f"✓ Stage 5:   messages.30.type.hn.10.parsed")
    print(f"\n✅ Result: HackerNews item #{item_id} ready for processing")
    print("=" * 80)


if __name__ == "__main__":
    demo()
