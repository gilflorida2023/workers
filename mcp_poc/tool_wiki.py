import json
import re
from pathlib import Path
from typing import Dict, Any, List, Optional

class ToolWiki:
    def __init__(self, wiki_path: str = None):
        from config import config
        self.wiki_path = Path(wiki_path or config.workspace.wiki_path)
        self.index = self._load_index()
        self._cache = {}

    def _load_index(self) -> Dict[str, Any]:
        index_file = self.wiki_path / "index.json"
        if index_file.exists():
            return json.loads(index_file.read_text())
        return {"tools": [], "guides": []}

    def get_tool_doc(self, tool_name: str) -> Optional[str]:
        for tool in self.index.get("tools", []):
            if tool["name"] == tool_name:
                wiki_file = self.wiki_path / tool["wiki_file"]
                if wiki_file.exists():
                    return wiki_file.read_text()
        return None

    def get_guide(self, guide_name: str) -> Optional[str]:
        for guide in self.index.get("guides", []):
            if guide["name"] == guide_name:
                wiki_file = self.wiki_path / guide["file"]
                if wiki_file.exists():
                    return wiki_file.read_text()
        return None

    def search(self, query: str) -> List[str]:
        results = []
        query_lower = query.lower()
        
        for tool in self.index.get("tools", []):
            if query_lower in tool["name"].lower() or query_lower in tool["description"].lower():
                results.append(f"Tool: {tool['name']} - {tool['description']}")
        
        for guide in self.index.get("guides", []):
            if query_lower in guide["name"].lower():
                results.append(f"Guide: {guide['name']}")
        
        return results

    def get_all_tool_names(self) -> List[str]:
        return [t["name"] for t in self.index.get("tools", [])]

    def get_all_guide_names(self) -> List[str]:
        return [g["name"] for g in self.index.get("guides", [])]