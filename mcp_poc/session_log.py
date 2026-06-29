"""Structured knowledge extraction and session logging.

Uses take-minutes for LLM-powered extraction (decisions, roadblocks,
action items) and derives files-touched from tool call history.
"""
import json
import hashlib
import logging
from datetime import datetime
from pathlib import Path
from typing import Any

from minutes.extractor import GatewayBackend, process_transcript
from minutes.config import Config as MinutesConfig
from minutes.models import ExtractionResult
from minutes.dedup import DedupStore

logger = logging.getLogger(__name__)

EXTRACTION_SYSTEM_PROMPT = """You are analyzing a coding agent conversation transcript.
Extract structured knowledge about the work performed, focusing on:
- Decisions: architectural choices, implementation decisions, and why
- Ideas: suggestions, alternative approaches discussed
- Questions/Roadblocks: issues encountered, bugs found, obstacles, open questions
- Accomplishments: what was completed or achieved (captured as action items with status done)
- Action Items: pending tasks, next steps, follow-up work not yet done
- Concepts: key technical concepts introduced or discussed
- Terms: abbreviations, jargon, or domain-specific terms

Be precise and concise. Only extract items explicitly discussed."""

EXTRACTION_USER_PROMPT = """Analyze this coding session transcript and extract structured knowledge.

Respond with ONLY a valid JSON object matching this schema:
{schema}

Transcript:
{transcript}

Be literal; do not embellish or infer."""


def format_history_as_transcript(history: list, task: str) -> str:
    """Format conversation history as a plain-text transcript for extraction."""
    lines = [f"Task: {task}", ""]
    for msg in history:
        role = msg.get("role", "unknown")
        content = msg.get("content", "")
        tool_calls = msg.get("tool_calls", [])

        if role == "user":
            if content:
                lines.append(f"User: {content}")
            lines.append("")

        elif role == "assistant":
            tc_text = ""
            if tool_calls:
                names = []
                for tc in tool_calls:
                    func = tc.get("function", {})
                    name = func.get("name", "")
                    args = func.get("arguments", {})
                    if isinstance(args, str):
                        args_str = args
                    else:
                        args_str = json.dumps(args)
                    names.append(f"{name}({args_str[:200]})")
                tc_text = f" [tools: {', '.join(names)}]"
            if content:
                lines.append(f"Assistant: {content}{tc_text}")
            elif tc_text:
                lines.append(f"Assistant:{tc_text}")
            lines.append("")

        elif role == "tool":
            truncated = content[:500] + "..." if len(content) > 500 else content
            lines.append(f"Tool Result: {truncated}")
            lines.append("")

        elif role == "system":
            lines.append(f"[System instruction omitted]")
            lines.append("")

    return "\n".join(lines)


def extract_files_from_history(history: list) -> list[dict]:
    """Scan tool calls in history for file paths, deduped by file."""
    file_tools: dict[str, set[str]] = {}
    for msg in history:
        tool_calls = msg.get("tool_calls", []) or []
        for tc in tool_calls:
            func = tc.get("function", {})
            name = func.get("name", "")
            args = func.get("arguments", {})
            if isinstance(args, str):
                try:
                    args = json.loads(args)
                except json.JSONDecodeError:
                    args = {}
            file_path = args.get("file_path") or args.get("path", "")
            if file_path:
                file_tools.setdefault(file_path, set()).add(name)
    return [{"file": fp, "tools": sorted(ts)} for fp, ts in file_tools.items()]


def _write_markdown(
    result: ExtractionResult,
    task: str,
    files_touched: list[dict],
    file_hash: str,
    input_label: str,
    backend_name: str,
    output_path: Path,
) -> str:
    """Write a rich markdown session log combining extraction + derived data."""
    now = datetime.now()
    date_str = now.strftime("%Y-%m-%d %H:%M:%S")
    filename = f"{now.strftime('%Y-%m-%d-%H-%M-%S')}.md"
    filepath = output_path / filename
    hash_short = file_hash[:12] if file_hash else "unknown"

    lines = [
        f"# Session — {date_str}",
        "",
        f"**Task:** {task}",
        f"**Backend:** {backend_name}",
        f"**Hash:** `{hash_short}`",
        "",
    ]

    # TLDR
    if result.tldr:
        lines.extend(["## Summary", result.tldr, ""])

    # Decisions
    if result.decisions:
        lines.append("## Decisions")
        for i, d in enumerate(result.decisions, 1):
            parts = [d.summary]
            if d.rationale:
                parts.append(f"(reason: {d.rationale})")
            if d.owner:
                parts.append(f"(owner: {d.owner})")
            lines.append(f"{i}. {' '.join(parts)}")
        lines.append("")

    # Roadblocks (mapped from questions)
    if result.questions:
        lines.append("## Roadblocks / Blockers")
        for q in result.questions:
            extra = f" — {q.context}" if q.context else ""
            lines.append(f"- {q.text}{extra}")
        lines.append("")

    # Action Items (accomplishments + pending)
    if result.action_items:
        lines.append("## Action Items")
        for a in result.action_items:
            owner = f" — Owner: {a.owner}" if a.owner else ""
            deadline = f", Due: {a.deadline}" if a.deadline else ""
            lines.append(f"- [x] {a.description}{owner}{deadline}")
        lines.append("")

    # Ideas
    if result.ideas:
        lines.append("## Ideas")
        for idea in result.ideas:
            lines.append(f"- **{idea.title}:** {idea.description}")
        lines.append("")

    # Files Touched
    if files_touched:
        lines.append("## Files Touched")
        for f in files_touched:
            tools_str = ", ".join(f["tools"])
            lines.append(f"- `{f['file']}` ({tools_str})")
        lines.append("")

    # Concepts
    if result.concepts:
        lines.append("## Concepts")
        for c in result.concepts:
            lines.append(f"- **{c.name}:** {c.definition}")
        lines.append("")

    # Terms
    if result.terms:
        lines.append("## Terminology")
        for t in result.terms:
            ctx = f" ({t.context})" if t.context else ""
            lines.append(f"- **{t.term}:** {t.definition}{ctx}")
        lines.append("")

    filepath.write_text("\n".join(lines).rstrip() + "\n")
    return str(filepath)


def _update_index(entry: str, index_path: Path):
    """Append a one-line entry to INDEX.md."""
    entries = []
    if index_path.exists():
        entries = index_path.read_text().splitlines()
    entries.append(entry)
    index_path.write_text("\n".join(entries) + "\n")


class SessionLogger:
    """Extract structured knowledge from agent sessions and persist to .session-log/."""

    def __init__(self, workspace_path: str, ollama_host: str, ollama_port: int, ollama_model: str):
        self.session_log_dir = Path(workspace_path) / ".session-log"
        self.session_log_dir.mkdir(parents=True, exist_ok=True)

        base_url = f"http://{ollama_host}:{ollama_port}/v1"
        self.backend = GatewayBackend(model=ollama_model, base_url=base_url)
        self.config = MinutesConfig(
            gateway_model=ollama_model,
            gateway_url=base_url,
            system_prompt=EXTRACTION_SYSTEM_PROMPT,
            extraction_prompt=EXTRACTION_USER_PROMPT,
            output_dir=str(self.session_log_dir),
            max_chunk_size=12000,
            chunk_overlap=200,
            max_retries=2,
        )
        self.dedup = DedupStore(str(self.session_log_dir))
        self.index_path = self.session_log_dir / "INDEX.md"

    def log_session(self, history: list, task: str) -> dict[str, Any]:
        """Extract structured knowledge and write session log.

        Returns dict with keys: cached, output_file, extraction, files_touched.
        """
        transcript = format_history_as_transcript(history, task)
        transcript_hash = hashlib.sha256(transcript.encode()).hexdigest()

        existing = self.dedup.is_processed(transcript_hash)
        if existing:
            logger.info(f"Session already logged: {existing}")
            files_touched = extract_files_from_history(history)
            return {"cached": True, "output_file": existing, "extraction": None, "files_touched": files_touched}

        try:
            extraction = process_transcript(self.backend, self.config, transcript)
        except Exception as e:
            logger.warning(f"Extraction failed: {e}")
            extraction = ExtractionResult(tldr=f"Extraction error: {e}")

        files_touched = extract_files_from_history(history)
        backend_label = f"ollama/{self.config.gateway_model}"

        markdown_path = _write_markdown(
            result=extraction,
            task=task[:200],
            files_touched=files_touched,
            file_hash=transcript_hash,
            input_label=f"session-{datetime.now().strftime('%Y%m%d-%H%M%S')}",
            backend_name=backend_label,
            output_path=self.session_log_dir,
        )

        self.dedup.record(transcript_hash, markdown_path, input_file=transcript)

        # INDEX.md entry
        tldr = extraction.tldr[:120] if extraction.tldr else "(no summary)"
        date_str = datetime.now().strftime("%Y-%m-%d %H:%M")
        rel_path = Path(markdown_path).name
        _update_index(f"- [{date_str}]({rel_path}) — {tldr}", self.index_path)

        logger.info(f"Session log written: {markdown_path}")
        return {
            "cached": False,
            "output_file": markdown_path,
            "extraction": extraction,
            "files_touched": files_touched,
        }
