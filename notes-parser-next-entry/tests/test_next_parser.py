"""Tests for NextParser."""
import sys
from pathlib import Path
import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from next_parser import NextParser, NextNoteData, ActionItem, Project

SAMPLE_NOTE = {
    "id": "abc123.xyz456",
    "title": "Next",
    "text": "Next\n\nProject Alpha\n\n- [ ] Write tests\n- [x] Set up repo\n\nProject Beta\n\n- [ ] Deploy\n- [ ] Monitor",
    "timestamps": {
        "created": "2026-01-15T09:00:00",
        "edited": "2026-01-15T10:00:00"
    }
}

TRAINING_NOTE = {
    "id": "training123",
    "title": "Training",
    "text": "☐ Bp\n  ☐ 2x30x13.6\n☐ Mr\n  ☐ 2x20x26",
    "timestamps": {"created": "2026-01-15T09:00:00", "edited": "2026-01-15T10:00:00"}
}


@pytest.fixture
def parser():
    return NextParser()


# --- can_parse tests ---

def test_can_parse_valid_next_note(parser):
    assert parser.can_parse(SAMPLE_NOTE) is True


def test_can_parse_case_insensitive(parser):
    note = {**SAMPLE_NOTE, "text": "NEXT\n\nProject A\n\n- [ ] Task"}
    assert parser.can_parse(note) is True


def test_can_parse_rejects_training_note(parser):
    assert parser.can_parse(TRAINING_NOTE) is False


def test_can_parse_rejects_time_entry(parser):
    note = {"text": "☐ 9 start\n☐ 930 work\n☐ 1700 stop", "title": "Log"}
    assert parser.can_parse(note) is False


def test_can_parse_rejects_non_dict(parser):
    assert parser.can_parse("not a dict") is False
    assert parser.can_parse(None) is False
    assert parser.can_parse([]) is False


def test_can_parse_rejects_empty_text(parser):
    assert parser.can_parse({"text": "", "title": "Next"}) is False
    assert parser.can_parse({"title": "Next"}) is False


# --- parse tests ---

def test_parse_returns_next_note_data(parser):
    result = parser.parse(SAMPLE_NOTE)
    assert isinstance(result, NextNoteData)


def test_parse_note_id(parser):
    result = parser.parse(SAMPLE_NOTE)
    assert result.note_id == "abc123.xyz456"


def test_parse_note_date(parser):
    result = parser.parse(SAMPLE_NOTE)
    assert result.note_date == "2026-01-15"
    assert result.formatted_date == "15/1"


def test_parse_projects_count(parser):
    result = parser.parse(SAMPLE_NOTE)
    assert len(result.projects) == 2


def test_parse_project_names(parser):
    result = parser.parse(SAMPLE_NOTE)
    names = [p.name for p in result.projects]
    assert "Project Alpha" in names
    assert "Project Beta" in names


def test_parse_action_items_pending(parser):
    result = parser.parse(SAMPLE_NOTE)
    alpha = next(p for p in result.projects if p.name == "Project Alpha")
    pending = [i for i in alpha.items if not i.completed]
    assert len(pending) == 1
    assert pending[0].text == "Write tests"


def test_parse_action_items_completed(parser):
    result = parser.parse(SAMPLE_NOTE)
    alpha = next(p for p in result.projects if p.name == "Project Alpha")
    done = [i for i in alpha.items if i.completed]
    assert len(done) == 1
    assert done[0].text == "Set up repo"


def test_parse_raw_text_preserved(parser):
    result = parser.parse(SAMPLE_NOTE)
    assert result.raw_text == SAMPLE_NOTE["text"]


# --- format_as_text tests ---

def test_format_as_text_contains_date(parser):
    result = parser.parse(SAMPLE_NOTE)
    text = NextParser.format_as_text(result)
    assert "15/1" in text


def test_format_as_text_contains_projects(parser):
    result = parser.parse(SAMPLE_NOTE)
    text = NextParser.format_as_text(result)
    assert "Project Alpha" in text
    assert "Project Beta" in text


def test_format_as_text_marks_completed(parser):
    result = parser.parse(SAMPLE_NOTE)
    text = NextParser.format_as_text(result)
    assert "✓" in text   # completed marker
    assert "•" in text   # pending marker


# --- format_as_org tests ---

def test_format_as_org_contains_todo_done(parser):
    result = parser.parse(SAMPLE_NOTE)
    org = NextParser.format_as_org(result)
    assert "TODO" in org
    assert "DONE" in org


def test_format_as_org_org_headings(parser):
    result = parser.parse(SAMPLE_NOTE)
    org = NextParser.format_as_org(result)
    assert "* Next for" in org
    assert "** Project Alpha" in org
