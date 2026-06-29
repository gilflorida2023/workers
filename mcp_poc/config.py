import yaml
from dataclasses import dataclass, field
from typing import Optional

@dataclass
class ScoutConfig:
    host: str = "localhost"
    port: int = 8080
    base_url: str = "http://localhost:8080/cgi-bin/mcp/tools"

@dataclass
class OllamaConfig:
    host: str = "192.168.0.7"
    port: int = 11434
    model: str = "qwen2.5-coder:7b"
    timeout: int = 300

@dataclass
class WorkspaceConfig:
    path: str = "/home/scout/projects/sandbox/workspace"
    wiki_path: str = "/home/scout/projects/sandbox/workspace/.wiki"

@dataclass
class AgentConfig:
    max_turns: int = 20
    temperature: float = 0.1

@dataclass
class ContextConfig:
    path: str = ""

@dataclass
class Config:
    scout: ScoutConfig = field(default_factory=ScoutConfig)
    ollama: OllamaConfig = field(default_factory=OllamaConfig)
    workspace: WorkspaceConfig = field(default_factory=WorkspaceConfig)
    agent: AgentConfig = field(default_factory=AgentConfig)
    context: ContextConfig = field(default_factory=ContextConfig)

    @classmethod
    def from_yaml(cls, path: str) -> "Config":
        with open(path, "r") as f:
            data = yaml.safe_load(f)

        config = cls()
        if "scout" in data:
            config.scout = ScoutConfig(**data["scout"])
        if "ollama" in data:
            config.ollama = OllamaConfig(**data["ollama"])
        if "workspace" in data:
            config.workspace = WorkspaceConfig(**data["workspace"])
        if "agent" in data:
            config.agent = AgentConfig(**data["agent"])
        if "context" in data:
            config.context = ContextConfig(**data["context"])
        return config

config = Config.from_yaml("/home/scout/projects/sandbox/mcp_poc/config.yaml")