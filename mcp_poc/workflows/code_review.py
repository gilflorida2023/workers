"""code_review pipeline — multi-file source code review (YAML-driven)."""

import logging
from pathlib import Path

from pipeline import Pipeline
from . import register

logger = logging.getLogger(__name__)


@register("code_review")
class CodeReviewPipeline(Pipeline):
    name = "code_review"
    description = "Multi-file source code review with per-file analysis and synthesis"
    yaml_file = Path(__file__).parent / "defs" / "code_review.yaml"

    async def _run(self, task: str) -> dict:
        result = await self._run_yaml(task, self.yaml_file)

        files = []
        for obs in result.get("analyze", []):
            f = obs.get("_key")
            if f and not obs.get("_skipped"):
                files.append(f)

        return {
            "session_id": self.session_id,
            "workflow": self.name,
            "files_analyzed": files,
            "observations": result.get("analyze", []),
            "synthesis": result.get("synthesize", {}),
        }
