from types import SimpleNamespace

from agent_keyboard.connection import (
    CONNECTION_BLUETOOTH,
    CONNECTION_RF24,
    CONNECTION_USB,
    classify_connection,
    connection_label,
    missing_control_message,
    should_enumerate_keyboard,
)


def test_classify_connection_usb_rf24_bluetooth():
    assert classify_connection(0x1AB5, "ROG", transport="USB") == CONNECTION_USB
    assert classify_connection(0x1A85, "Azoth", transport="USB") == CONNECTION_RF24
    assert classify_connection(0x193E, "Falchion") == CONNECTION_RF24
    assert classify_connection(0x19F8, "Scope NX") == CONNECTION_RF24
    assert classify_connection(0x1AB5, "ROG", transport="Bluetooth") == CONNECTION_BLUETOOTH
    assert classify_connection(0x1AB5, "ROG", transport="BluetoothLowEnergy") == CONNECTION_BLUETOOTH
    assert classify_connection(0x1AB5, "ROG", bus_type=2) == CONNECTION_BLUETOOTH
    assert classify_connection(0x1ACE, "ROG OMNI RECEIVER") == CONNECTION_RF24


def test_connection_labels():
    assert connection_label(CONNECTION_USB) == "USB"
    assert connection_label(CONNECTION_RF24) == "2.4G"
    assert connection_label(CONNECTION_BLUETOOTH) == "Bluetooth"


def test_should_enumerate_omni_keyboard_not_mouse():
    assert should_enumerate_keyboard(0x1ACE, "ROG OMNI RECEIVER", 0x01, 0x06)
    assert not should_enumerate_keyboard(0x1ACE, "ROG OMNI RECEIVER", 0x01, 0x02)
    assert should_enumerate_keyboard(0x1ACE, "ROG OMNI RECEIVER", 0xFF00, 0x0001)
    assert not should_enumerate_keyboard(0x1B84, "ROG Pelta", 0x01, 0x06)
    assert should_enumerate_keyboard(0x1AB5, "ROG Strix Scope II RX", 0x01, 0x06)
    assert should_enumerate_keyboard(0x1AB5, "ROG Strix Scope II RX", 0xFF00, 0x0001)


def test_missing_control_message_bluetooth():
    device = SimpleNamespace(
        product="ROG Strix Scope II RX",
        product_id=0x1AB5,
        connection=CONNECTION_BLUETOOTH,
    )
    message = missing_control_message([device])
    assert "Bluetooth" in message
    assert "Aura Direct" in message


def test_missing_control_message_omni():
    device = SimpleNamespace(
        product="ROG OMNI RECEIVER",
        product_id=0x1ACE,
        connection=CONNECTION_RF24,
    )
    message = missing_control_message([device])
    assert "Omni Receiver" in message
    assert "USB" in message
