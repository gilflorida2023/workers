"""code_review pipeline — multi-file source code review.

Phases:
  1. discover — list relevant source files for the task
  2. analyze  — per-file LLM analysis (batch, sequential)
  3. synthesize — combine per-file observations into a unified report
"""

import json
import logging

from pipeline import Pipeline
from . import register

logger = logging.getLogger(__name__)


ANALYSIS_SCHEMA = {
    "type": "object",
    "properties": {
        "observations": {"type": "array", "items": {"type": "string"}},
        "issues": {"type": "array", "items": {"type": "string"}},
        "suggestions": {"type": "array", "items": {"type": "string"}},
        "concepts": {"type": "array", "items": {"type": "string"}},
    },
}

SYNTHESIS_SCHEMA = {
    "type": "object",
    "properties": {
        "summary": {"type": "string"},
        "priority_fixes": {"type": "array", "items": {"type": "string"}},
        "architecture_notes": {"type": "array", "items": {"type": "string"}},
        "cross_cutting": {"type": "array", "items": {"type": "string"}},
    },
}


DISCOVER_SYSTEM = (
    "You are a code reviewer. Given a task and a list of available files, "
    "identify which source code files are most relevant to reviewing. "
    "Ignore non-code files (READMEs, configs, go.sum, etc.) unless the "
    "task specifically asks about them."
)

DISCOVER_USER_TEMPLATE = (
    "Task: {task}\n\n"
    "Available files in the workspace:\n{file_list}\n\n"
    "List the files most relevant for this review. Respond with the JSON "
    "schema provided."
)


ANALYZE_SYSTEM_TEMPLATE = (
    "You are an expert {language} code reviewer. Focus on: {task}. "
    "Output valid JSON matching the schema. Be precise and concise."
)

ANALYZE_USER_TEMPLATE = (
    "Review this {language} file:\n\n"
    "```{language}\n{content}\n```\n\n"
    "Check for: correctness, performance issues, idiomatic code, "
    "edge cases, security concerns, and any bugs."
)


SYNTHESIZE_SYSTEM = (
    "You are a senior engineer synthesizing per-file code review findings "
    "into a unified report. Group findings by priority, note cross-cutting "
    "concerns that span multiple files, and provide actionable recommendations."
)

SYNTHESIZE_USER_TEMPLATE = (
    "Task: {task}\n\n"
    "Per-file observations:\n{observations}\n\n"
    "Synthesize into a unified code review. Output valid JSON matching the schema."
)


@register("code_review")
class CodeReviewPipeline(Pipeline):
    name = "code_review"
    description = "Multi-file source code review with per-file analysis and synthesis"

    async def _run(self, task: str) -> dict:
        # ── Phase 1: Discover ──────────────────────────────────────────
        file_list = self._list_files()
        file_tree = "\n".join(file_list)

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

        files = discover_result.get("files", file_list)
        if not files:
            logger.warning("No files discovered, falling back to all files")
            files = file_list

        # ── Phase 2: Per-file analysis (sequential batch) ──────────────
        def prepare_analyze(fp: str):
            content = self._read_file(fp)
            lang = self._detect_language(fp)
            return {
                "system": ANALYZE_SYSTEM_TEMPLATE.format(language=lang, task=task),
                "user": ANALYZE_USER_TEMPLATE.format(language=lang, content=content),
            }

        observations = await self._phase_batch(
            "analyze",
            files,
            prepare_fn=prepare_analyze,
            output_schema=ANALYSIS_SCHEMA,
            item_key_fn=lambda fp: fp.replace("/", "_").replace(".", "_"),
        )

        # ── Phase 3: Synthesize ────────────────────────────────────────
        obs_summary = json.dumps(
            [{k: v for k, v in o.items() if not k.startswith("_")}
             for o in observations],
            indent=2,
        )

        synthesis = await self._phase(
            "synthesize",
            system=SYNTHESIZE_SYSTEM,
            user=SYNTHESIZE_USER_TEMPLATE.format(
                task=task, observations=obs_summary
            ),
            output_schema=SYNTHESIS_SCHEMA,
        )

        return {
            "session_id": self.session_id,
            "workflow": self.name,
            "files_analyzed": files,
            "observations": observations,
            "synthesis": synthesis,
        }
