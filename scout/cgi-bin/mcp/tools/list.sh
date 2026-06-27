#!/bin/bash
set -euo pipefail

INPUT=$(cat)

cat << 'TOOLS'
{
  "tools": [
    {"name": "worker1.compile", "description": "Compile worker1 (wheel-2310 parallel)", "input_schema": {"type": "object", "properties": {}}},
    {"name": "worker1.run", "description": "Run worker1 with limit", "input_schema": {"type": "object", "properties": {"limit": {"type": "integer", "default": 100}}}},
    {"name": "worker1.verify", "description": "Verify worker1 KAT hash", "input_schema": {"type": "object", "properties": {"limit": {"type": "integer", "default": 100}}}},
    {"name": "worker1.config", "description": "Get worker1 config", "input_schema": {"type": "object", "properties": {}}},
    {"name": "worker2.compile", "description": "Compile worker2 (wheel-2310 sequential)", "input_schema": {"type": "object", "properties": {}}},
    {"name": "worker2.run", "description": "Run worker2 with limit", "input_schema": {"type": "object", "properties": {"limit": {"type": "integer", "default": 100}}}},
    {"name": "worker2.verify", "description": "Verify worker2 KAT hash", "input_schema": {"type": "object", "properties": {"limit": {"type": "integer", "default": 100}}}},
    {"name": "worker2.config", "description": "Get worker2 config", "input_schema": {"type": "object", "properties": {}}},
    {"name": "baseline.compile", "description": "Compile baseline (wheel-210 parallel)", "input_schema": {"type": "object", "properties": {}}},
    {"name": "baseline.run", "description": "Run baseline with limit", "input_schema": {"type": "object", "properties": {"limit": {"type": "integer", "default": 100}}}},
    {"name": "baseline.verify", "description": "Verify baseline KAT hash", "input_schema": {"type": "object", "properties": {"limit": {"type": "integer", "default": 100}}}},
    {"name": "baseline.config", "description": "Get baseline config", "input_schema": {"type": "object", "properties": {}}},
    {"name": "kat_verify.verify", "description": "Verify KAT hash against manifest", "input_schema": {"type": "object", "properties": {"prime_count": {"type": "integer"}, "kat_hash": {"type": "string"}}}},
    {"name": "manifest.get", "description": "Get manifest A000040.json", "input_schema": {"type": "object", "properties": {}}},
    {"name": "judge.heuristic", "description": "Judge worker results via heuristic", "input_schema": {"type": "object", "properties": {"entity": {"type": "string"}, "worker_results": {"type": "array", "items": {"type": "object"}}}}},
    {"name": "arena.get_context", "description": "Get current match context: baseline code, problem tier, limit", "input_schema": {"type": "object", "properties": {"worker_id": {"type": "string"}}}},
    {"name": "arena.read_file", "description": "Read a file from worker sandbox", "input_schema": {"type": "object", "properties": {"worker_id": {"type": "string"}, "path": {"type": "string"}}}},
    {"name": "arena.write_file", "description": "Write a file to worker sandbox", "input_schema": {"type": "object", "properties": {"worker_id": {"type": "string"}, "path": {"type": "string"}, "content": {"type": "string"}}}},
    {"name": "arena.submit", "description": "Submit worker code for judging", "input_schema": {"type": "object", "properties": {"worker_id": {"type": "string"}}}},
    {"name": "arena.leaderboard", "description": "Get current leaderboard", "input_schema": {"type": "object", "properties": {}}},
    {"name": "arena.status", "description": "Get worker status and history", "input_schema": {"type": "object", "properties": {"worker_id": {"type": "string"}}}},
    {"name": "arena.match_result", "description": "Get last match result for a worker", "input_schema": {"type": "object", "properties": {"worker_id": {"type": "string"}}}},
    {"name": "arena.run_match", "description": "Run a full match between two workers", "input_schema": {"type": "object", "properties": {"worker1_host": {"type": "string"}, "worker2_host": {"type": "string"}, "model": {"type": "string"}}}},
    {"name": "arena.tool_prove", "description": "Proving ground: test worker agents' ability to compile and run code to answer a question", "input_schema": {"type": "object", "properties": {"worker1_host": {"type": "string"}, "worker2_host": {"type": "string"}, "model": {"type": "string"}}}}
  ]
}
TOOLS
