"""context_load pipeline — warm up the agent with compressed codebase knowledge.

Phases:
  1. discover — list relevant source files for the task
  2. summarize — per-file summarisation (batch, sequential)
  3. build-blob — combine summaries into a cohesive codebase overview
"""

import logging

from pipeline import Pipeline
from . import register

logger = logging.getLogger(__name__)


SUMMARIZE_SCHEMA = {
    "type": "object",
    "properties": {
        "file": {"type": "string"},
        "purpose": {"type": "string"},
        "key_symbols": {"type": "array", "items": {"type": "string"}},
        "dependencies": {"type": "array", "items": {"type": "string"}},
        "notable": {"type": "array", "items": {"type": "string"}},
    },
}

BLOB_SCHEMA = {
    "type": "object",
    "properties": {
        "context_blob": {"type": "string"},
    },
}


DISCOVER_SYSTEM = (
    "You are preparing context for a coding agent. Given a task and "
    "available files, list only the relevant source code files that the "
    "agent needs to understand. Prioritise .go, .py, .js, .rs, .c, .cpp "
    "files. Ignore generated, vendored, or config files unless relevant."
)

DISCOVER_USER_TEMPLATE = (
    "Task: {task}\n\n"
    "Available files:\n{file_list}\n\n"
    "List the files the agent needs to understand. Output valid JSON."
)


SUMMARIZE_SYSTEM_TEMPLATE = (
    "You are reading a {language} source file. Produce a terse summary "
    "(≤200 tokens) covering: the file's purpose, key exported symbols, "
    "dependencies it imports, and anything notable for a developer working "
    "on: {task}. Output valid JSON matching the schema."
)

SUMMARIZE_USER_TEMPLATE = (
    "File: {file}\n\n"
    "```{language}\n{content}\n```"
)


BUILD_BLOB_SYSTEM = (
    "You are a technical writer. Combine the per-file summaries below "
    "into a cohesive codebase overview. Keep it under 3000 tokens. "
    "Focus on: project structure, entry points, key types and functions, "
    "how files relate to each other, and anything critical for: {task}. "
    "Output valid JSON matching the schema."
)

BUILD_BLOB_USER_TEMPLATE = (
    "Task: {task}\n\n"
    "Per-file summaries:\n{summaries}\n\n"
    "Produce a markdown codebase overview. Output JSON with a "
    "'context_blob' key containing the markdown."
)


@register("context_load")
class ContextLoadPipeline(Pipeline):
    name = "context_load"
    description = "Summarise relevant source files into a compressed context blob for the agent"

    async def _run(self, task: str) -> dict:
        # ── Phase 1: Discover ──────────────────────────────────────────
        all_files = self._list_files()
        file_tree = "\n".join(all_files)

        discover_result = await self._phase(
            "discover",
            system=DISCOVER_SYSTEM,
            user=DISCOVER_USER_TEMPLATE.format(task=task, file_list=file_tree),
            output_schema={
                "type": "object",
                "properties": {
                    "files": {"type": "array", "items": {"type": "string"}},
                },
            },
        )

        files = discover_result.get("files", all_files)
        if not files:
            logger.warning("No files discovered, falling back to all files")
            files = all_files

        # ── Phase 2: Per-file summarisation (sequential batch) ─────────
        def prepare_summarise(fp: str):
            content = self._read_file(fp)
            lang = self._detect_language(fp)
            return {
                "system": SUMMARIZE_SYSTEM_TEMPLATE.format(language=lang, task=task),
                "user": SUMMARIZE_USER_TEMPLATE.format(
                    file=fp, language=lang, content=content
                ),
            }

        summaries = await self._phase_batch(
            "summarize",
            files,
            prepare_fn=prepare_summarise,
            output_schema=SUMMARIZE_SCHEMA,
            item_key_fn=lambda fp: fp.replace("/", "_").replace(".", "_"),
        )

        # ── Phase 3: Build context blob ────────────────────────────────
        summaries_text = "\n".join(
            f"--- {s.get('file', s.get('_key', '?'))} ---\n"
            f"Purpose: {s.get('purpose', '')}\n"
            f"Symbols: {', '.join(s.get('key_symbols', []))}\n"
            f"Deps: {', '.join(s.get('dependencies', []))}\n"
            f"Notable: {', '.join(s.get('notable', []))}"
            for s in summaries
        )

        blob_result = await self._phase(
            "build-blob",
            system=BUILD_BLOB_SYSTEM.format(task=task),
            user=BUILD_BLOB_USER_TEMPLATE.format(task=task, summaries=summaries_text),
            output_schema=BLOB_SCHEMA,
        )

        context_blob = blob_result.get("context_blob", "")

        blob_path = self.session_dir / "context-blob.md"
        blob_path.write_text(context_blob)
        logger.info("Context blob written to %s", blob_path)

        self._append_conversation({
            "role": "sys",
            "phase": "build-blob",
            "summary": f"Context blob built: {len(context_blob)} chars",
            "file_count": len(files),
        })

        return {
            "session_id": self.session_id,
            "workflow": self.name,
            "files_summarized": files,
            "context_blob_path": str(blob_path),
            "context_blob_length": len(context_blob),
        }