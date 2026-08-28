"""HID transport for the Aura control collection (usage page 0xFF00).

Prefers the `hid` Python package (cython-hidapi). Falls back to ctypes-loaded
libhidapi. Enumeration never opens the boot-keyboard interface.
"""

from __future__ import annotations

import ctypes
import ctypes.util
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

from .constants import (
    ASUS_VID,
    CMD_EFFECT,
    CMD_QUERY,
    CMD_SAVE,
    CONTROL_INTERFACE,
    CONTROL_USAGE,
    CONTROL_USAGE_PAGE,
    EFFECT_ARG,
    EFFECT_PER_LED_FLAG,
    QUERY_LAYOUT,
    QUERY_VERSION,
    REPORT_LENGTH,
    SAVE_ARG,
    SUPPORTED_PIDS,
)
from .layout import PROFILE, KeyboardProfile
from .protocol import build_frame, packet_views
from .rgb import Rgb


class KeyboardDevice(Protocol):
    is_open: bool
    profile: KeyboardProfile
    info: dict

    def write_frame(self, pixels: list[Rgb]) -> None: ...
    def read_info(self) -> dict: ...
    def apply_static(self, color: Rgb, brightness: int = 20) -> None: ...
    def close(self) -> None: ...


@dataclass(frozen=True, slots=True)
class HidMatch:
    path: str
    vendor_id: int
    product_id: int
    product: str
    usage_page: int
    usage: int
    interface_number: int


def _hid_path(path: object) -> str:
    if path is None:
        return ""
    if isinstance(path, bytes):
        return path.decode("utf-8", "replace")
    return str(path)


def _hid_path_bytes(path: str | bytes) -> bytes:
    if isinstance(path, bytes):
        return path
    return path.encode("utf-8")


class DeviceError(RuntimeError):
    pass


def _is_control(match: HidMatch) -> bool:
    if match.vendor_id != ASUS_VID:
        return False
    if match.product_id not in SUPPORTED_PIDS:
        return False
    if match.usage_page == CONTROL_USAGE_PAGE and match.usage == CONTROL_USAGE:
        return True
    if match.interface_number == CONTROL_INTERFACE:
        return True
    return False


def is_scope_control(match: HidMatch) -> bool:
    return _is_control(match)



def _score(match: HidMatch) -> tuple[int, int, int]:
    usage_hit = int(match.usage_page == CONTROL_USAGE_PAGE and match.usage == CONTROL_USAGE)
    iface_hit = int(match.interface_number == CONTROL_INTERFACE)
    return (usage_hit, iface_hit, -match.interface_number)


class NullDevice:
    """In-memory sink for tests and `--simulate`."""

    def __init__(self, profile: KeyboardProfile = PROFILE) -> None:
        self.profile = profile
        self.is_open = True
        self.info = {"backend": "null", "product": profile.name}
        self.last_frame: list[Rgb] | None = None
        self.frames = 0

    def write_frame(self, pixels: list[Rgb]) -> None:
        if len(pixels) != self.profile.led_count:
            raise ValueError("wrong pixel count")
        self.last_frame = list(pixels)
        self.frames += 1
        build_frame(pixels, self.profile)  # keep protocol exercised

    def read_info(self) -> dict:
        return {"firmware": "simulate", "layout": 0, **self.info}

    def apply_static(self, color: Rgb, brightness: int = 20) -> None:
        self.write_frame([color.scale(brightness / 100)] * self.profile.led_count)

    def close(self) -> None:
        self.is_open = False


class HidApiDevice:
    def __init__(self, handle: object, match: HidMatch, profile: KeyboardProfile = PROFILE) -> None:
        self._handle = handle
        self.match = match
        self.profile = profile
        self.is_open = True
        self.info = {
            "backend": "hidapi",
            "path": match.path,
            "vid": match.vendor_id,
            "pid": match.product_id,
            "product": match.product,
            "usage_page": match.usage_page,
            "usage": match.usage,
            "interface": match.interface_number,
        }
        self._buf = bytearray(profile.frame_buffer_size)

    def write_frame(self, pixels: list[Rgb]) -> None:
        build_frame(pixels, self.profile, self._buf)
        for packet in packet_views(self._buf, self.profile):
            self._write(bytes(packet))

    def read_info(self) -> dict:
        self._flush()
        self._write(_command(CMD_QUERY, QUERY_VERSION))
        version_raw = self._read(timeout_ms=80)
        firmware = "unknown"
        if version_raw:
            # hidapi strips report-id, so offsets match OpenRGB (not Win32 +1).
            firmware = f"{version_raw[6]:02X}.{version_raw[5]:02X}.{version_raw[4]:02X}"
        self._flush()
        self._write(_command(CMD_QUERY, QUERY_LAYOUT))
        layout_raw = self._read(timeout_ms=80)
        layout = -1
        if layout_raw:
            layout = layout_raw[4] * 100 + layout_raw[5]
        return {"firmware": firmware, "layout": layout, **self.info}

    def apply_static(self, color: Rgb, brightness: int = 20) -> None:
        buf = bytearray(REPORT_LENGTH)
        buf[1] = CMD_EFFECT
        buf[2] = EFFECT_ARG
        buf[3] = 0x00  # static
        buf[5] = 30
        buf[6] = max(0, min(100, brightness))
        buf[9] = EFFECT_PER_LED_FLAG
        buf[10] = color.r
        buf[11] = color.g
        buf[12] = color.b
        self._write(bytes(buf))

    def save_to_flash(self) -> None:
        self._write(_command(CMD_SAVE, SAVE_ARG))

    def close(self) -> None:
        if not self.is_open:
            return
        close = getattr(self._handle, "close", None)
        if close is not None:
            close()
        self.is_open = False

    def _write(self, report: bytes) -> None:
        written = self._handle.write(report)
        if written is not None and written < 0:
            raise DeviceError("hid write failed")

    def _read(self, timeout_ms: int = 50) -> bytes | None:
        read = getattr(self._handle, "read", None)
        if read is None:
            return None
        try:
            data = read(REPORT_LENGTH, timeout_ms)
        except TypeError:
            data = read(REPORT_LENGTH)
        if not data:
            return None
        return bytes(data)

    def _flush(self) -> None:
        read = getattr(self._handle, "read", None)
        if read is None:
            return
        while True:
            try:
                data = read(REPORT_LENGTH, 0)
            except TypeError:
                break
            if not data:
                break


def _command(*payload: int) -> bytes:
    buf = bytearray(REPORT_LENGTH)
    for i, value in enumerate(payload, start=1):
        buf[i] = value
    return bytes(buf)


def enumerate_matches() -> list[HidMatch]:
    matches = _enumerate_hid_module()
    if matches is None:
        matches = _enumerate_ctypes()
    return sorted(matches or [], key=_score, reverse=True)


def find_keyboard(simulate: bool = False) -> KeyboardDevice:
    if simulate:
        return NullDevice()
    all_matches = enumerate_matches()
    matches = [m for m in all_matches if _is_control(m)]
    if not matches:
        # Still list ASUS PIDs so probe can explain usage-page misses.
        asus = [m for m in all_matches if m.vendor_id == ASUS_VID]
        if asus:
            names = sorted({f"{m.product or 'ASUS'} (0x{m.product_id:04X})" for m in asus})
            raise DeviceError(
                "ROG Strix Scope II RX/NX not found (need PID 0x1AB5 or 0x1AB3). "
                f"USB currently shows: {', '.join(names)}. "
                "Plug the keyboard in over USB — the Omni Receiver is a different device."
            )
        raise DeviceError(
            "ROG Strix Scope II RX/NX not found (VID 0x0B05 PID 0x1AB5/0x1AB3). "
            "Plug it in over USB and close Armoury Crate / OpenRGB if those are running."
        )
    last_error: Exception | None = None
    for match in matches:
        try:
            handle = _open_path(match.path)
            return HidApiDevice(handle, match)
        except Exception as exc:  # noqa: BLE001
            last_error = exc
    raise DeviceError(f"could not open Aura control interface: {last_error}")


def _enumerate_hid_module() -> list[HidMatch] | None:
    try:
        _preload_libhidapi()
        import hid  # type: ignore
    except Exception:
        return None
    found: list[HidMatch] = []
    try:
        devices = hid.enumerate(ASUS_VID)
    except TypeError:
        devices = hid.enumerate()
    for item in devices:
        pid = int(item.get("product_id") or 0)
        vid = int(item.get("vendor_id") or 0)
        if vid != ASUS_VID:
            continue
        product = item.get("product_string") or ""
        found.append(
            HidMatch(
                path=_hid_path(item.get("path")),
                vendor_id=vid,
                product_id=pid,
                product=product if isinstance(product, str) else str(product),
                usage_page=int(item.get("usage_page") or 0),
                usage=int(item.get("usage") or 0),
                interface_number=int(item.get("interface_number") if item.get("interface_number") is not None else -1),
            )
        )
    return found


def _open_path(path: str):
    try:
        _preload_libhidapi()
        import hid  # type: ignore

        device = hid.device()
        device.open_path(_hid_path_bytes(path))
        try:
            device.set_nonblocking(True)
        except Exception:
            pass
        return device
    except Exception:
        return _ctypes_open_path(path)


# ----- ctypes libhidapi fallback -------------------------------------------------

class _HidDeviceInfo(ctypes.Structure):
    pass


_HidDeviceInfo._fields_ = [
    ("path", ctypes.c_char_p),
    ("vendor_id", ctypes.c_ushort),
    ("product_id", ctypes.c_ushort),
    ("serial_number", ctypes.c_wchar_p),
    ("release_number", ctypes.c_ushort),
    ("manufacturer_string", ctypes.c_wchar_p),
    ("product_string", ctypes.c_wchar_p),
    ("usage_page", ctypes.c_ushort),
    ("usage", ctypes.c_ushort),
    ("interface_number", ctypes.c_int),
    ("next", ctypes.POINTER(_HidDeviceInfo)),
]


def _hidapi_search_paths() -> list[str]:
    return [
        "/opt/homebrew/lib/libhidapi.dylib",
        "/opt/homebrew/lib/libhidapi.0.dylib",
        "/opt/homebrew/opt/hidapi/lib/libhidapi.dylib",
        "/usr/local/lib/libhidapi.dylib",
        "/usr/local/lib/libhidapi.0.dylib",
    ]


def _preload_libhidapi() -> None:
    """Help the `hid` wheel find Homebrew's dylib on Apple Silicon."""
    for path in _hidapi_search_paths():
        if Path(path).exists():
            try:
                ctypes.CDLL(path)
                return
            except OSError:
                continue


def _load_libhidapi() -> ctypes.CDLL | None:
    for path in _hidapi_search_paths():
        if Path(path).exists():
            try:
                return ctypes.CDLL(path)
            except OSError:
                continue
    for name in ("hidapi", "hidapi-hidraw", "hidapi-libusb", "libhidapi"):
        found = ctypes.util.find_library(name)
        if found:
            try:
                return ctypes.CDLL(found)
            except OSError:
                continue
    return None


class _CtypesHandle:
    def __init__(self, lib: ctypes.CDLL, ptr: ctypes.c_void_p) -> None:
        self._lib = lib
        self._ptr = ptr

    def write(self, data: bytes) -> int:
        buf = (ctypes.c_ubyte * len(data)).from_buffer_copy(data)
        n = self._lib.hid_write(self._ptr, buf, len(data))
        return int(n)

    def read(self, length: int, timeout_ms: int = 50) -> bytes:
        buf = (ctypes.c_ubyte * length)()
        n = self._lib.hid_read_timeout(self._ptr, buf, length, timeout_ms)
        if n <= 0:
            return b""
        return bytes(buf[:n])

    def close(self) -> None:
        if self._ptr:
            self._lib.hid_close(self._ptr)
            self._ptr = None


_LIB = None


def _lib() -> ctypes.CDLL:
    global _LIB
    if _LIB is None:
        loaded = _load_libhidapi()
        if loaded is None:
            raise DeviceError(
                "hidapi is not installed. On macOS: `brew install hidapi` then "
                "`uv pip install hid` (or rely on libhidapi.dylib via ctypes)."
            )
        loaded.hid_init()
        loaded.hid_enumerate.restype = ctypes.POINTER(_HidDeviceInfo)
        loaded.hid_enumerate.argtypes = [ctypes.c_ushort, ctypes.c_ushort]
        loaded.hid_free_enumeration.argtypes = [ctypes.POINTER(_HidDeviceInfo)]
        loaded.hid_open_path.restype = ctypes.c_void_p
        loaded.hid_open_path.argtypes = [ctypes.c_char_p]
        loaded.hid_write.restype = ctypes.c_int
        loaded.hid_write.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t]
        loaded.hid_read_timeout.restype = ctypes.c_int
        loaded.hid_read_timeout.argtypes = [
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_ubyte),
            ctypes.c_size_t,
            ctypes.c_int,
        ]
        loaded.hid_close.argtypes = [ctypes.c_void_p]
        _LIB = loaded
    return _LIB


def _enumerate_ctypes() -> list[HidMatch]:
    try:
        lib = _lib()
    except DeviceError:
        return []
    head = lib.hid_enumerate(ASUS_VID, 0)
    found: list[HidMatch] = []
    try:
        node = head
        while node:
            info = node.contents
            product = info.product_string or ""
            found.append(
                HidMatch(
                    path=_hid_path(info.path),
                    vendor_id=info.vendor_id,
                    product_id=info.product_id,
                    product=product,
                    usage_page=info.usage_page,
                    usage=info.usage,
                    interface_number=info.interface_number,
                )
            )
            node = info.next
    finally:
        if head:
            lib.hid_free_enumeration(head)
    return found


def _ctypes_open_path(path: str | bytes) -> _CtypesHandle:
    lib = _lib()
    raw = _hid_path_bytes(path)
    ptr = lib.hid_open_path(raw)
    if not ptr:
        try:
            lib.hid_error.restype = ctypes.c_wchar_p
            lib.hid_error.argtypes = [ctypes.c_void_p]
            detail = lib.hid_error(None) or ""
        except Exception:
            detail = ""
        raise DeviceError(f"hid_open_path failed for {_hid_path(path)}" + (f": {detail}" if detail else ""))
    return _CtypesHandle(lib, ptr)
