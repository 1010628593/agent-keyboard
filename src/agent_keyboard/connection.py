"""USB / 2.4G / Bluetooth classification for ASUS HID keyboards."""

from __future__ import annotations

from .constants import (
    CONTROL_USAGE,
    CONTROL_USAGE_PAGE,
    GENERIC_DESKTOP_USAGE_PAGE,
    HID_BUS_BLUETOOTH,
    IGNORED_PIDS,
    KEYBOARD_USAGE,
    OMNI_RECEIVER_PID,
    RF24_PIDS,
)

CONNECTION_USB = "usb"
CONNECTION_RF24 = "rf24"
CONNECTION_BLUETOOTH = "bluetooth"

_LABELS = {
    CONNECTION_USB: "USB",
    CONNECTION_RF24: "2.4G",
    CONNECTION_BLUETOOTH: "Bluetooth",
}


def connection_label(kind: str) -> str:
    return _LABELS.get(kind, "USB")


def is_omni_receiver(product_id: int, product: str = "") -> bool:
    return product_id == OMNI_RECEIVER_PID or "omni receiver" in (product or "").lower()


def is_aura_control(usage_page: int, usage: int) -> bool:
    return usage_page == CONTROL_USAGE_PAGE and usage == CONTROL_USAGE


def is_boot_keyboard(usage_page: int, usage: int) -> bool:
    return usage_page == GENERIC_DESKTOP_USAGE_PAGE and usage == KEYBOARD_USAGE


def classify_connection(
    product_id: int,
    product: str = "",
    bus_type: int | None = None,
    transport: str | None = None,
) -> str:
    text = (transport or "").strip()
    if text.lower().startswith("bluetooth") or bus_type == HID_BUS_BLUETOOTH:
        return CONNECTION_BLUETOOTH
    if product_id in RF24_PIDS or is_omni_receiver(product_id, product):
        return CONNECTION_RF24
    return CONNECTION_USB


def should_enumerate_keyboard(
    product_id: int,
    product: str,
    usage_page: int,
    usage: int,
) -> bool:
    if product_id in IGNORED_PIDS:
        return False
    aura = is_aura_control(usage_page, usage)
    keyboard = is_boot_keyboard(usage_page, usage)
    if is_omni_receiver(product_id, product):
        return aura or keyboard
    return aura or keyboard


def missing_control_message(asus: list[object]) -> str:
    """Explain why a recognized ASUS HID device cannot be opened for lighting."""
    names = sorted(
        {
            f"{getattr(item, 'product', None) or 'ASUS'} "
            f"(0x{int(getattr(item, 'product_id', 0)):04X}, "
            f"{connection_label(str(getattr(item, 'connection', CONNECTION_USB)))})"
            for item in asus
        }
    )
    seen = ", ".join(names)
    kinds = {str(getattr(item, "connection", CONNECTION_USB)) for item in asus}
    if CONNECTION_BLUETOOTH in kinds and CONNECTION_USB not in kinds:
        return (
            f"Recognized {seen}, but Bluetooth does not expose Aura Direct. "
            "Plug in USB (or a 2.4G receiver with usage FF00:0001) to control lights."
        )
    if any(is_omni_receiver(int(getattr(item, "product_id", 0)), str(getattr(item, "product", "") or "")) for item in asus):
        return (
            f"Recognized {seen}. Omni Receiver is not an Aura Direct keyboard. "
            "Plug the keyboard in over USB to control lights."
        )
    return (
        "ROG Strix Scope II RX/NX not found (need PID 0x1AB5 or 0x1AB3 with Aura Direct). "
        f"Currently visible: {seen}."
    )
