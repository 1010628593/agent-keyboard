# Protocol references (not committed)

These trees are local study copies. The 107-LED table and Direct packet
layout used by this project are already baked into `src/agent_keyboard/`.

```bash
git clone --depth 1 https://github.com/bbfox0703/RSS_II_RGB.git vendor/RSS_II_RGB

mkdir -p vendor/openrgb-tuf
curl -fsSL -o vendor/openrgb-tuf/AsusAuraTUFKeyboardController.cpp \
  https://raw.githubusercontent.com/CalcProgrammer1/OpenRGB/master/Controllers/AsusAuraUSBController/AsusAuraTUFKeyboardController/AsusAuraTUFKeyboardController.cpp
```

- RSS_II_RGB: GPL-3.0, hardware-verified on Scope II RX (PID `0x1AB5`)
- OpenRGB TUF driver: GPL-2.0-or-later, origin of the Direct HID command
