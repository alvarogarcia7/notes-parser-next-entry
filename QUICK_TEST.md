# Quick Pipeline Test Guide

## Single Command to Test Everything

```bash
cd /var/tmp/vibe-kanban/worktrees/08e4-implement-this-f
./run_pipeline_test.sh
```

That's it! The script will:

1. ✅ Check prerequisites (Docker, Python, files)
2. ✅ Start NATS server (or reuse existing)
3. ✅ Start all 4 pipeline components
4. ✅ Publish sample data
5. ✅ Wait for processing
6. ✅ Verify output files
7. ✅ Validate JSON
8. ✅ Show results
9. ✅ Clean up

## What You'll See

```
════════════════════════════════════════════════════════
Prerequisites Check
════════════════════════════════════════════════════════
→ Checking for required tools...
✓ Docker found
✓ Python3 found
✓ google-keep-notes-parser found
✓ training-parser-antlr4 found
...

════════════════════════════════════════════════════════
Starting NATS
════════════════════════════════════════════════════════
→ Starting NATS in Docker...
✓ NATS started and ready

════════════════════════════════════════════════════════
Starting Pipeline Components
════════════════════════════════════════════════════════
→ Starting Writer (listens for parsed sessions)...
✓ Writer started (PID: 12345)
→ Starting Training Listener (parses with ANTLR4)...
✓ Training Listener started (PID: 12346)
→ Starting Router (routes by type)...
✓ Router started (PID: 12347)

════════════════════════════════════════════════════════
Publishing Sample Data
════════════════════════════════════════════════════════
→ Running Publisher (reads JSON files)...
✓ Published sample/training/sample1.json (note_id: aaaaaaaaaaa.bbbbbbbbbbbbbbbb)

════════════════════════════════════════════════════════
Results Verification
════════════════════════════════════════════════════════
✓ Pipeline executed successfully!
✓ Generated 1 output file(s)

Output Files:
  /tmp/training/0.json (1.2K)

Sample Output (first file, first 30 lines):
---
{
  "workout_id": "w_20260123_000000",
  "type": "set-centric",
  "date": "2026-01-23",
  "location": "",
  "notes": "",
  "statistics": {},
  "exercises": [
    {
      "name": "Bench Press",
      "equipment": "other",
      "sets": [
        {
          "setNumber": 1,
          "repetitions": 30,
          "weight": {
            "amount": 13.6,
            "unit": "kg"
          }
        },
        ...
---

✓ All output files are valid JSON (1/1)
✓ Output contains 'workout_id' field
✓ Output contains 'exercises' field
✓ Output contains 'date' field

════════════════════════════════════════════════════════
Test Complete
════════════════════════════════════════════════════════
✓ All pipeline components executed successfully!
✓ Sample data published from google-keep-notes-parser
✓ Messages routed by type using ParserRegistry
✓ Training messages parsed with ANTLR4
✓ Parsed sessions written to /tmp/training

Pipeline Verification Summary:
  Input:  Google Keep notes (JSON files)
  Step 1: Publisher → messages.10.raw
  Step 2: Router → messages.20.type.training
  Step 3: Training Listener → messages.30.type.training.10.parsed
  Step 4: Writer → /tmp/training/*.json
  Output: 1 parsed workout session(s)

Component Status:
  ✓ Writer running
  ✓ Training Listener running
  ✓ Router running

===================================================
NATS Pipeline Test PASSED ✓
===================================================
```

## Script Features

### Automatic Checks
- Verifies Docker is installed and running
- Checks Python 3 is available
- Confirms all required files exist
- Validates sample data is present

### Smart NATS Management
- Reuses existing NATS if already running
- Starts NATS in Docker if needed
- Waits up to 30s for NATS to be ready
- Cleans up NATS container after test

### Comprehensive Logging
- All components log to `/tmp/nats_*.log`
- Logs are displayed on errors
- Process IDs are shown for debugging

### Output Validation
- Verifies JSON syntax
- Checks for expected fields (workout_id, exercises, date)
- Shows sample output
- Reports file sizes and counts

### Clean Shutdown
- Stops all background processes
- Removes NATS container
- Cleans up log files (on exit)

## Troubleshooting

### If test fails:

**"Docker not found"**
```bash
# Install Docker from https://docs.docker.com/get-docker/
docker --version
```

**"Python3 not found"**
```bash
# Install Python 3.9+
python3 --version
```

**"No output files generated"**
- Check component logs: `cat /tmp/nats_*.log`
- Verify NATS is running: `nc -z localhost 4222 && echo "NATS OK"`
- Check sample files exist: `ls google-keep-notes-parser/sample/**/*.json`

**"Some files are invalid JSON"**
- Component failed to parse notes
- Check Training Listener log: `cat /tmp/nats_training_listener.log`
- Sample data might not match ANTLR4 grammar

## Manual Testing

If you want to run components separately:

```bash
# Terminal 1: Start NATS
docker run -p 4222:4222 nats:latest

# Terminal 2: Start Writer
cd training-parser-antlr4 && python nats_writer.py

# Terminal 3: Start Training Listener  
cd training-parser-antlr4 && python nats_training_listener.py

# Terminal 4: Start Router
cd google-keep-notes-parser && python nats_router.py

# Terminal 5: Run Publisher
cd google-keep-notes-parser && python nats_publisher.py --input-dir sample

# Terminal 6: Check results
watch -n 1 'ls -la /tmp/training/'
```

## Environment Variables

```bash
# Change NATS URL
export NATS_URL=nats://nats.example.com:4222
./run_pipeline_test.sh

# Custom output directory (modify script)
OUTPUT_DIR=/custom/path ./run_pipeline_test.sh
```

## Script Sections

| Section | Purpose |
|---------|---------|
| Prerequisites Check | Verify Docker, Python, files, sample data |
| Starting NATS | Start or reuse NATS server |
| Preparing Test | Clean output directory |
| Starting Pipeline Components | Start Writer, Listener, Router (in order) |
| Publishing Sample Data | Run Publisher |
| Processing | Wait for messages to flow through pipeline |
| Results Verification | Check output files, validate JSON, verify content |
| Final Summary | Show component status and test results |

## Expected Output

- **Input**: Google Keep notes from `sample/training/*.json`
- **Processing**: 4 components (Publisher → Router → Training Listener → Writer)
- **Output**: Parsed workouts in `/tmp/training/*.json`
- **Example**: `{"workout_id": "w_20260123_000000", "exercises": [...]}`

## Next Steps

After successful test:

1. **Review output**: `cat /tmp/training/0.json`
2. **Scale up**: Add more sample notes
3. **Monitor**: Use `nats-top` to watch message flow
4. **Extend**: Add post-processors for other types (toggl, next, hn)
5. **Deploy**: Use Docker Compose for production setup

---

**Test Script**: `run_pipeline_test.sh` (9.7 KB)  
**Execution Time**: ~20 seconds (mostly waiting for NATS startup)  
**Success Criteria**: Output files generated + valid JSON + expected fields
