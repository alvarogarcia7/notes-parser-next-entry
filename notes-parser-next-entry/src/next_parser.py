import re
import json
from dataclasses import dataclass
from typing import Any, Dict, List
from datetime import datetime
from pathlib import Path


@dataclass
class ActionItem:
    text: str
    completed: bool


@dataclass
class Project:
    name: str
    items: List[ActionItem]


@dataclass
class NextNoteData:
    note_id: str
    note_date: str
    formatted_date: str
    projects: List[Project]
    raw_text: str


class NextParser:
    def can_parse(self, note_data: Any) -> bool:
        if not isinstance(note_data, dict):
            return False

        text: str = note_data.get('text', '')
        if not text:
            return False

        lines = text.strip().split('\n')
        first_line = lines[0].strip() if lines else ''

        return first_line.lower() == 'next'

    def parse(self, note_data: Any) -> NextNoteData:
        if not isinstance(note_data, dict):
            raise ValueError("note_data must be a dictionary")

        text: str = note_data.get('text', '')
        timestamps: Dict[str, str] = note_data.get('timestamps', {})
        created: str = timestamps.get('created', '')

        note_date, formatted_date = self._parse_date(created)
        projects: List[Project] = self._extract_projects(text)

        return NextNoteData(
            note_id=note_data.get('id', ''),
            note_date=note_date,
            formatted_date=formatted_date,
            projects=projects,
            raw_text=text
        )

    def _parse_date(self, timestamp: str) -> tuple[str, str]:
        if not timestamp:
            return '', ''

        try:
            if 'T' in timestamp:
                dt = datetime.fromisoformat(timestamp.split('.')[0])
            else:
                dt = datetime.strptime(timestamp.split('.')[0], '%Y-%m-%d %H:%M:%S')

            iso_date = dt.date().isoformat()
            day = str(dt.day)
            month = str(dt.month)
            formatted = f"{day}/{month}"

            return iso_date, formatted
        except Exception:
            return timestamp, timestamp

    def _extract_projects(self, text: str) -> List[Project]:
        projects: List[Project] = []
        lines = text.strip().split('\n')

        current_project: str | None = None
        current_items: List[ActionItem] = []

        for line in lines[1:]:  # Skip the "Next" header
            stripped = line.strip()

            if not stripped:
                continue

            if not stripped.startswith('- ['):
                # Project name line
                if current_project is not None:
                    projects.append(Project(name=current_project, items=current_items))
                current_project = stripped
                current_items = []
            else:
                completed = '[x]' in stripped or '[X]' in stripped
                text_match = re.search(r'-\s*\[[xX\s]\]\s*(.*)', stripped)
                if text_match:
                    item_text = text_match.group(1)
                    current_items.append(ActionItem(text=item_text, completed=completed))

        if current_project is not None:
            projects.append(Project(name=current_project, items=current_items))

        return projects

    def get_schema(self) -> Dict[str, Any]:
        schema_path = Path(__file__).parent.parent / "schemas" / "next.schema.json"
        with open(schema_path, 'r') as f:
            return json.load(f)

    @staticmethod
    def format_as_text(result: NextNoteData) -> str:
        output: List[str] = [f"Next for {result.formatted_date}"]
        output.append(f"Total Projects: {len(result.projects)}\n")

        for project in result.projects:
            output.append(f"{project.name}")
            for item in project.items:
                status = "✓" if item.completed else "•"
                output.append(f"  {status} {item.text}")
            output.append("")

        return "\n".join(output)

    @staticmethod
    def format_as_org(result: NextNoteData) -> str:
        output: List[str] = [f"* Next for {result.formatted_date}"]
        output.append(f"Total Projects: {len(result.projects)}\n")

        for project in result.projects:
            output.append(f"** {project.name}")
            for item in project.items:
                status = "DONE" if item.completed else "TODO"
                output.append(f"   - [{status}] {item.text}")
            output.append("")

        return "\n".join(output)
