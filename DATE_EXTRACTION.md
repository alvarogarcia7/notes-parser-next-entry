# Date Extraction Feature for Publishers

Both the Google Keep and Apple Notes publishers now extract and include dates in all messages published to `messages.10.raw` topic.

## Overview

Every message published to NATS includes a `date` field in ISO 8601 format (YYYY-MM-DD):

```json
{
  "id": "msg-uuid-123",
  "date": "2026-05-15",
  "note": {
    "id": "note-123",
    "title": "Team Meeting 15/05",
    ...
  }
}
```

## Date Priority

Dates are extracted using this priority:

1. **Title override** (highest priority) — If the note title contains a date in `dd/mm` format, that date is used
2. **Creation date** — Falls back to `created` or `createdTime` field
3. **Modification date** — Falls back to `modified` or `updatedTime` field  
4. **Other date fields** — Falls back to `timestamp` or `date` fields
5. **None** — If no date found, `date` field is set to `null`

## Title Date Format

Dates in note titles must be in `dd/mm` format to be recognized:

**Valid formats:**
- `Meeting 15/05` ✓
- `15/05 Team Sync` ✓
- `Project 5/5` ✓ (single digit months/days)
- `01/01 New Year` ✓ (with leading zeros)

**Invalid formats:**
- `Meeting 2026-05-15` ✗ (ISO format not recognized)
- `May 15` ✗ (text month names not recognized)
- `15/05/2026` ✗ (year included)
- `32/13` ✗ (invalid day/month)

## Date Validation

The date extraction validates:
- Days: 1-31
- Months: 1-12
- Calendar rules: February has max 29 days, April/June/September/November have 30 days

Invalid dates like "31/02" or "32/13" are rejected and fall back to other date sources.

## Year Handling

For title dates in `dd/mm` format:
- Always uses the current year
- Example: If title says "15/05" in 2026, date becomes "2026-05-15"

For dates from note metadata:
- Preserves the year from the creation/modification timestamp
- Example: Created on "2026-05-02T10:30:00Z" becomes "2026-05-02"

## Testing

### Unit Tests

34 comprehensive tests validate all aspects:

```bash
cd google-keep-notes-parser
python3 -m pytest test_date_extractor.py test_publisher_integration.py -v
```

**Test coverage:**
- Date extraction from titles (7 tests)
- Fallback to creation/modification dates (13 tests)
- Message formatting (3 tests)
- Real-world scenarios (8 tests)
- JSON serialization and batch processing (3 tests)

### Running Tests

```bash
# Run all tests
python3 -m pytest test_date_extractor.py test_publisher_integration.py -v

# Run specific test class
python3 -m pytest test_date_extractor.py::TestExtractDateFromTitle -v

# Run with coverage
python3 -m pytest test_date_extractor.py test_publisher_integration.py --cov=date_extractor
```

## Integration with Publishers

### Google Keep Publisher

```python
from date_extractor import format_message_with_date

note_data = {
    "id": "note-123",
    "title": "Meeting 15/05",
    "created": "2026-05-02T10:30:00Z"
}

message = {
    "id": "uuid-123",
    "note": note_data
}

# Add date field (extracts from title if present)
message = format_message_with_date(message, note_data)

# Result: message["date"] == "2026-05-15"
```

### Apple Notes Publisher

Same usage pattern - simply call `format_message_with_date()` with the note data:

```python
message = format_message_with_date(message, apple_note_data)
```

## Examples

### Example 1: Title Override

```python
note = {
    "title": "Project Update 20/05",
    "created": "2026-05-02T10:00:00Z"  # Different from title date
}

date = get_note_date(note)
# Result: "2026-05-20" (from title, not creation date)
```

### Example 2: Fallback to Creation Date

```python
note = {
    "title": "Regular Meeting Notes",  # No date in title
    "created": "2026-05-15T14:30:00Z"
}

date = get_note_date(note)
# Result: "2026-05-15" (from creation date)
```

### Example 3: Complex Title with Multiple Dates

```python
note = {
    "title": "Sprint Planning 15/05 - Sprint 18/05"  # Two dates
}

date = get_note_date(note)
# Result: "2026-05-15" (first date found)
```

### Example 4: Invalid Date Handling

```python
note = {
    "title": "Meeting 32/05",  # Invalid day (32)
    "created": "2026-05-10T10:00:00Z"
}

date = get_note_date(note)
# Result: "2026-05-10" (falls back to creation date)
```

## Performance

Date extraction is lightweight:
- Regex matching: O(n) where n = title length
- Date parsing: O(1) constant time
- No external dependencies beyond Python stdlib

Typical extraction time: <1ms per note

## Usage in Messages

The date field enables:

1. **Temporal filtering** — Query notes by date range
2. **Chronological sorting** — Sort parsed messages by date
3. **Archive organization** — Group results by date
4. **Audit trails** — Track when notes were created vs. processed

## Architecture

```
Publisher (Google Keep or Apple Notes)
    ↓
Note JSON
    ↓
date_extractor.format_message_with_date()
    ├─ Extract from title (dd/mm)
    ├─ OR fallback to created date
    ├─ OR fallback to modified date
    └─ Format as YYYY-MM-DD
    ↓
messages.10.raw (NATS topic)
{
  "id": "uuid",
  "date": "2026-05-15",  ← Added here
  "note": {...}
}
    ↓
Parsers (time, training, next)
```

## Shared Utility

The `date_extractor.py` module is shared between:
- `google-keep-notes-parser/date_extractor.py`
- `notes-exporter/date_extractor.py`

Both publishers use the same logic for consistency.

## Future Enhancements

- [ ] Support for other date formats (dd-mm, mm/dd, etc.)
- [ ] Timezone awareness and handling
- [ ] Heuristic detection of date contexts (e.g., "Due: 15/05")
- [ ] Caching of parsed dates for performance
- [ ] Configurable date extraction rules per publisher

## Troubleshooting

### Date not being extracted

Check that:
1. Title contains date in `dd/mm` format
2. Format has word boundaries (not `abc15/05def`)
3. Date is valid (day 1-31, month 1-12)

### Unexpected year in ISO date

- Title dates always use current year
- Metadata dates preserve original year
- This is intentional to handle recurring notes

### Test failures

Run with verbose output:
```bash
python3 -m pytest test_date_extractor.py -vv
```

Check that all 34 tests pass before deploying.
