"""Agent dashboard state and event schema."""

from __future__ import annotations

from dataclasses import dataclass, replace
from enum import Enum
from time import monotonic

from .constants import DONE_HOLD_SECONDS
from .layout import AGENT_KEY_NAMES


class AgentStatus(str, Enum):
    IDLE = "idle"
    RUNNING = "running"  # thinking
    TOOL = "tool"
    APPROVAL = "approval"
    DONE = "done"
    ERROR = "error"


STATUS_ALIASES = {
    "idle": AgentStatus.IDLE,
    "thinking": AgentStatus.RUNNING,
    "running": AgentStatus.RUNNING,
    "tool": AgentStatus.TOOL,
    "tool_calling": AgentStatus.TOOL,
    "tool-calling": AgentStatus.TOOL,
    "approval": AgentStatus.APPROVAL,
    "waiting_approval": AgentStatus.APPROVAL,
    "waiting-approval": AgentStatus.APPROVAL,
    "done": AgentStatus.DONE,
    "completed": AgentStatus.DONE,
    "complete": AgentStatus.DONE,
    "error": AgentStatus.ERROR,
    "failed": AgentStatus.ERROR,
}


@dataclass(frozen=True, slots=True)
class AgentSpec:
    slot: str
    agent_id: str
    name: str
    key_name: str


@dataclass(slots=True)
class AgentSlot:
    spec: AgentSpec
    status: AgentStatus = AgentStatus.IDLE
    context: float = 0.0
    progress: float | None = None
    message: str = ""
    done_until: float | None = None

    @property
    def fill(self) -> float:
        if self.progress is not None:
            return _clamp01(self.progress)
        return _clamp01(self.context)


@dataclass(frozen=True, slots=True)
class AgentEvent:
    agent: str
    status: AgentStatus | None = None
    context: float | None = None
    progress: float | None = None
    message: str | None = None

    @classmethod
    def from_dict(cls, payload: dict) -> AgentEvent:
        raw_status = payload.get("status")
        status = None
        if raw_status is not None:
            key = str(raw_status).strip().lower().replace(" ", "_")
            if key not in STATUS_ALIASES:
                raise ValueError(f"unknown status: {raw_status!r}")
            status = STATUS_ALIASES[key]
        context = payload.get("context")
        progress = payload.get("progress")
        return cls(
            agent=str(payload.get("agent") or payload.get("id") or "").strip(),
            status=status,
            context=None if context is None else float(context),
            progress=None if progress is None else float(progress),
            message=None if payload.get("message") is None else str(payload["message"]),
        )


DEFAULT_AGENTS: tuple[AgentSpec, ...] = (
    AgentSpec("f1", "codex", "Codex", "F1"),
    AgentSpec("f2", "claude", "Claude Code", "F2"),
    AgentSpec("f3", "hermes", "Hermes", "F3"),
    AgentSpec("f4", "cursor", "Cursor", "F4"),
    AgentSpec("f5", "pi", "Pi", "F5"),
    AgentSpec("f6", "workbuddy", "Workbuddy", "F6"),
)

LEGACY_AGENT_IDS = {
    "spring": "hermes",
    "data": "cursor",
    "browser": "pi",
    "local": "workbuddy",
}


class Dashboard:
    def __init__(self, specs: tuple[AgentSpec, ...] = DEFAULT_AGENTS) -> None:
        self.slots = [AgentSlot(spec) for spec in specs]
        self._by_alias: dict[str, AgentSlot] = {}
        for slot in self.slots:
            for alias in (slot.spec.slot, slot.spec.agent_id, slot.spec.key_name.lower()):
                self._by_alias[alias.lower()] = slot

    def resolve(self, agent: str) -> AgentSlot:
        key = agent.strip().lower()
        if key.startswith("f") and key[1:].isdigit():
            key = f"f{int(key[1:])}"
        key = LEGACY_AGENT_IDS.get(key, key)
        slot = self._by_alias.get(key)
        if slot is None:
            raise KeyError(f"unknown agent: {agent!r}")
        return slot

    def apply(self, event: AgentEvent, now: float | None = None) -> AgentSlot:
        if not event.agent:
            raise ValueError("event.agent is required")
        slot = self.resolve(event.agent)
        now = monotonic() if now is None else now
        if event.status is not None:
            slot.status = event.status
            if event.status is AgentStatus.DONE:
                slot.done_until = now + DONE_HOLD_SECONDS
            else:
                slot.done_until = None
        if event.context is not None:
            slot.context = _clamp01(event.context)
        if event.progress is not None:
            slot.progress = _clamp01(event.progress)
        if event.message is not None:
            slot.message = event.message
        return slot

    def tick(self, now: float | None = None) -> None:
        now = monotonic() if now is None else now
        for slot in self.slots:
            if (
                slot.status is AgentStatus.DONE
                and slot.done_until is not None
                and now >= slot.done_until
            ):
                slot.status = AgentStatus.IDLE
                slot.done_until = None
                slot.message = ""

    def snapshot(self) -> list[AgentSlot]:
        return [
            replace(
                AgentSlot(spec=slot.spec),
                status=slot.status,
                context=slot.context,
                progress=slot.progress,
                message=slot.message,
                done_until=slot.done_until,
            )
            for slot in self.slots
        ]

    def to_dict(self) -> dict:
        return {
            "agents": [
                {
                    "slot": slot.spec.slot,
                    "id": slot.spec.agent_id,
                    "name": slot.spec.name,
                    "key": slot.spec.key_name,
                    "status": slot.status.value,
                    "context": slot.context,
                    "progress": slot.progress,
                    "message": slot.message,
                }
                for slot in self.slots
            ]
        }

    def any_status(self, *statuses: AgentStatus) -> bool:
        wanted = set(statuses)
        return any(slot.status in wanted for slot in self.slots)

    def active_slots(self) -> list[AgentSlot]:
        return [slot for slot in self.slots if slot.status is not AgentStatus.IDLE]

    def primary(self) -> AgentSlot | None:
        rank = {
            AgentStatus.ERROR: 0,
            AgentStatus.APPROVAL: 1,
            AgentStatus.TOOL: 2,
            AgentStatus.RUNNING: 3,
            AgentStatus.DONE: 4,
            AgentStatus.IDLE: 5,
        }
        active = self.active_slots()
        if not active:
            return None
        return min(active, key=lambda slot: (rank[slot.status], AGENT_KEY_NAMES.index(slot.spec.key_name)))


def _clamp01(value: float) -> float:
    if value < 0:
        return 0.0
    if value > 1:
        return 1.0
    return float(value)


def specs_from_config(rows: list[dict]) -> tuple[AgentSpec, ...]:
    if not rows:
        return DEFAULT_AGENTS
    specs: list[AgentSpec] = []
    for index, row in enumerate(rows):
        slot = str(row.get("slot") or f"f{index + 1}").lower()
        key_name = str(row.get("key") or slot.upper())
        if key_name.upper() in AGENT_KEY_NAMES:
            key_name = key_name.upper()
        specs.append(
            AgentSpec(
                slot=slot,
                agent_id=str(row.get("id") or slot),
                name=str(row.get("name") or slot),
                key_name=key_name,
            )
        )
    return tuple(specs)
