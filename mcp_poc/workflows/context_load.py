"""context_load pipeline — warm up the agent with compressed codebase knowledge (YAML-driven)."""

import logging
from pathlib import Path

from pipeline import Pipeline
from . import register

logger = logging.getLogger(__name__)


@register("context_load")
class ContextLoadPipeline(Pipeline):
    name = "context_load"
    description = "Summarise relevant source files into a compressed context blob for the agent"
    yaml_file = Path(__file__).parent / "defs" / "context_load.yaml"

    async def _run(self, task: str) -> dict:
        result = await self._run_yaml(task, self.yaml_file)

        blob = result.get("build-blob", {}).get("context_blob", "")
        blob_path = self.session_dir / "context-blob.md"
        blob_path.write_text(blob)
        logger.info("Context blob written to %s (length: %d)", blob_path, len(blob))

        self._append_conversation({
            "role": "sys",
            "phase": "build-blob",
            "summary": f"Context blob built: {len(blob)} chars",
        })

        files = []
        for s in result.get("summarize", []):
            f = s.get("_key")
            if f and not s.get("_skipped"):
                files.append(f)

        return {
            "session_id": self.session_id,
            "workflow": self.name,
            "files_summarized": files,
            "context_blob_path": str(blob_path),
            "context_blob_length": len(blob),
        }
