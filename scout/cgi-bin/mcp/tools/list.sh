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
    {"name": "judge.heuristic", "description": "Judge worker results via heuristic", "input_schema": {"type": "object", "properties": {"entity": {"type": "string"}, "worker_results": {"type": "array", "items": {"type": "object"}}}}}
  ]
}
TOOLS
