import json
from typing import List, Dict, Any, Optional
from tool_wiki import ToolWiki

class ContextManager:
    def __init__(self, wiki: ToolWiki):
        self.wiki = wiki
        self.history = []
        self.max_history = 20

    def add_message(self, role: str, content: str, tool_calls: List = None, tool_call_id: str = None):
        self.history.append({
            "role": role,
            "content": content,
            "tool_calls": tool_calls,
            "tool_call_id": tool_call_id
        })
        if len(self.history) > self.max_history:
            self.history = self.history[-self.max_history:]

    def get_relevant_context(self, query: str) -> Optional[str]:
        query_lower = query.lower()
        relevant = []
        
        # Check for tool mentions
        for tool_name in self.wiki.get_all_tool_names():
            if tool_name.lower() in query_lower:
                doc = self.wiki.get_tool_doc(tool_name)
                if doc:
                    relevant.append(f"=== {tool_name} ===\n{doc[:2000]}")
        
        # Check for guide mentions
        for guide_name in self.wiki.get_all_guide_names():
            if guide_name.lower() in query_lower:
                doc = self.wiki.get_guide(guide_name)
                if doc:
                    relevant.append(f"=== Guide: {guide_name} ===\n{doc[:2000]}")
        
        if not relevant:
            # Return getting started guide by default
            getting_started = self.wiki.get_guide("getting_started")
            if getting_started:
                return getting_started[:3000]
            return None
        
        return "\n\n".join(relevant)

    def get_history_summary(self) -> str:
        if not self.history:
            return ""
        recent = self.history[-10:]
        summary = []
        for msg in recent:
            if msg["role"] == "user":
                summary.append(f"User: {msg['content'][:100]}")
            elif msg["role"] == "assistant":
                summary.append(f"Assistant: {msg['content'][:100]}")
            elif msg["role"] == "tool":
                summary.append(f"Tool result: {msg['content'][:100]}")
        return "\n".join(summary)