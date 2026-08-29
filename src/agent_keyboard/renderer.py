"""32 FPS render loop. Device write is the natural throttle."""

from __future__ import annotations

import threading
import time
from typing import Callable

from .constants import DEFAULT_TARGET_FPS
from .device import KeyboardDevice, NullDevice
from .overlay import OverlayLease, apply_overlay, inactive_overlay_snapshot
from .rgb import WHITE, Rgb
from .scenes import RenderStyle, render_dashboard
from .state import Dashboard


class Engine:
    def __init__(
        self,
        dashboard: Dashboard,
        device: KeyboardDevice,
        *,
        fps: int = DEFAULT_TARGET_FPS,
        style: RenderStyle = RenderStyle.DASHBOARD,
        idle_white: float = 0.05,
        on_frame: Callable[[list[Rgb], float], None] | None = None,
    ) -> None:
        self.dashboard = dashboard
        self.device = device
        self.fps = max(1, min(fps, 60))
        self.style = style
        self.idle_white = idle_white
        self.on_frame = on_frame
        self.frames = 0
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self.last_pixels: list[Rgb] | None = None
        self._overlay: OverlayLease | None = None

    def apply_event(self, event) -> None:
        with self._lock:
            self.dashboard.apply(event)

    def snapshot(self) -> dict:
        with self._lock:
            now = time.monotonic()
            overlay = self._live_overlay(now)
            payload = self.dashboard.to_dict()
            payload["overlay"] = overlay.snapshot(now) if overlay else inactive_overlay_snapshot()
            return payload

    def health(self) -> dict:
        with self._lock:
            return {"ok": True, "frames": self.frames, "device": self.device.info}

    def apply_overlay(self, lease: OverlayLease) -> dict:
        with self._lock:
            self._overlay = lease
            snap = self.dashboard.to_dict()
            snap["overlay"] = lease.snapshot(lease.started_at)
            return snap

    def release_overlay(self) -> dict:
        with self._lock:
            self._overlay = None
            snap = self.dashboard.to_dict()
            snap["overlay"] = inactive_overlay_snapshot()
            return snap

    def _live_overlay(self, now: float) -> OverlayLease | None:
        overlay = self._overlay
        if overlay is None:
            return None
        if overlay.expired(now):
            self._overlay = None
            return None
        return overlay

    def start(self) -> None:
        if self._thread is not None:
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, name="agent-keyboard-render", daemon=True)
        self._thread.start()

    def stop(self, restore: bool = True) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=1.5)
            self._thread = None
        if restore:
            try:
                self.device.apply_static(WHITE, brightness=8)
            except Exception:
                pass
        self.device.close()

    def _run(self) -> None:
        period = 1.0 / self.fps
        while not self._stop.is_set():
            started = time.monotonic()
            with self._lock:
                self.dashboard.tick(now=started)
                overlay = self._live_overlay(started)
                pixels = render_dashboard(
                    self.dashboard,
                    started,
                    style=self.style,
                    idle_white=self.idle_white,
                )
                pixels = apply_overlay(pixels, overlay, started)
            self.last_pixels = pixels
            try:
                self.device.write_frame(pixels)
            except Exception:
                if not isinstance(self.device, NullDevice):
                    raise
            self.frames += 1
            if self.on_frame is not None:
                self.on_frame(pixels, started)
            remaining = period - (time.monotonic() - started)
            if remaining > 0:
                self._stop.wait(remaining)
