"""Agent Keyboard — ROG Strix Scope II RX as a 107-pixel Agent dashboard."""

from .constants import ASUS_VID, SCOPE_II_NX_PID, SCOPE_II_RX_PID
from .rgb import Rgb
from .state import AgentEvent, AgentStatus, Dashboard

__version__ = "0.1.0"
__all__ = [
    "ASUS_VID",
    "SCOPE_II_NX_PID",
    "SCOPE_II_RX_PID",
    "AgentEvent",
    "AgentStatus",
    "Dashboard",
    "Rgb",
]
