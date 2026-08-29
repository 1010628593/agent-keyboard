"""agent-keyboard CLI."""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import replace
from pathlib import Path

from .bridge import serve
from .config import load_config
from .constants import DEFAULT_BRIDGE_HOST, DEFAULT_BRIDGE_PORT
from .device import DeviceError, NullDevice, enumerate_matches, find_keyboard, is_scope_control
from .preview import render_grid
from .renderer import Engine
from .scenes import RenderStyle
from .state import AgentEvent, AgentStatus, Dashboard


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="agent-keyboard",
        description="Drive a ROG Strix Scope II RX as an Agent status dashboard.",
    )
    parser.add_argument("--config", type=Path, help="path to agents.toml")
    parser.add_argument(
        "--style",
        choices=["dashboard", "cinematic"],
        help="override render style from config",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("enumerate", help="list ASUS HID collections")
    probe_p = sub.add_parser("probe", help="open the Aura interface and read firmware")
    probe_p.add_argument("--simulate", action="store_true")
    serve_p = sub.add_parser("serve", help="render loop + HTTP event bridge")
    serve_p.add_argument("--simulate", action="store_true", help="do not open HID; render to memory / terminal")
    serve_p.add_argument("--host", default=None)
    serve_p.add_argument("--port", type=int, default=None)
    serve_p.add_argument("--preview", action="store_true", help="also print a terminal grid")

    send_p = sub.add_parser("send", help="push one Agent event (requires serve, or --direct)")
    send_p.add_argument("agent")
    send_p.add_argument("status")
    send_p.add_argument("--context", type=float, default=None)
    send_p.add_argument("--progress", type=float, default=None)
    send_p.add_argument("--message", default=None)
    send_p.add_argument("--url", default=None, help="bridge URL, default http://127.0.0.1:7420/event")
    send_p.add_argument("--direct", action="store_true", help="open HID and apply once without the daemon")

    demo_p = sub.add_parser("demo", help="cycle the Codex slot through every Agent scene")
    demo_p.add_argument("--simulate", action="store_true")
    demo_p.add_argument("--preview", action="store_true")
    demo_p.add_argument("--hold", type=float, default=2.5)

    idle_p = sub.add_parser("idle", help="force all slots idle and paint once")
    idle_p.add_argument("--simulate", action="store_true")
    mcp_p = sub.add_parser("mcp", help="stdio MCP server (talks to the HTTP bridge)")
    mcp_p.add_argument(
        "--url",
        default=None,
        help="bridge base URL, default http://127.0.0.1:7420",
    )
    args = parser.parse_args(argv)

    cfg = load_config(args.config)
    if args.style:
        cfg = replace(cfg, style=RenderStyle(args.style))

    if args.cmd == "enumerate":
        return cmd_enumerate()
    if args.cmd == "probe":
        return cmd_probe(simulate=getattr(args, "simulate", False))
    if args.cmd == "serve":
        return cmd_serve(
            cfg,
            host=args.host or cfg.host,
            port=args.port or cfg.port,
            simulate=getattr(args, "simulate", False),
            preview=args.preview,
        )
    if args.cmd == "send":
        return cmd_send(args, cfg)
    if args.cmd == "demo":
        return cmd_demo(
            cfg,
            simulate=getattr(args, "simulate", False),
            preview=args.preview,
            hold=args.hold,
        )
    if args.cmd == "idle":
        return cmd_idle(cfg, simulate=getattr(args, "simulate", False))
    if args.cmd == "mcp":
        from .mcp import serve_stdio

        return serve_stdio(args.url)
    return 1


def cmd_enumerate() -> int:
    try:
        matches = enumerate_matches()
    except DeviceError as exc:
        print(exc, file=sys.stderr)
        return 1
    if not matches:
        print("no ASUS HID devices found.")
        print("Plug in the Scope II RX over USB. If hidapi is missing: brew install hidapi")
        return 1
    for match in matches:
        mark = " *" if is_scope_control(match) else ""
        print(
            f"pid=0x{match.product_id:04X}  iface={match.interface_number:>2}  "
            f"usage={match.usage_page:04X}:{match.usage:04X}  {match.product!r}{mark}"
        )
        print(f"  {match.path}")
    print("(* = Aura control collection)")
    return 0


def cmd_probe(simulate: bool) -> int:
    try:
        device = find_keyboard(simulate=simulate)
    except DeviceError as exc:
        print(exc, file=sys.stderr)
        return 1
    try:
        info = device.read_info()
        print(json.dumps(info, indent=2))
        return 0
    finally:
        device.close()


def _open_engine(cfg, simulate: bool, preview: bool = False) -> Engine:
    device = find_keyboard(simulate=simulate)
    dashboard = Dashboard(cfg.agents)
    engine = Engine(
        dashboard,
        device,
        fps=cfg.fps,
        style=cfg.style,
        idle_white=cfg.idle_white,
    )
    if preview:

        def _on_frame(pixels, _now):  # noqa: ANN001
            if engine.frames % max(1, cfg.fps // 4) == 0:
                sys.stdout.write("\033[H\033[2J" + render_grid(pixels) + "\n")
                sys.stdout.flush()

        engine.on_frame = _on_frame
    return engine


def cmd_serve(cfg, host: str, port: int, simulate: bool, preview: bool) -> int:
    try:
        engine = _open_engine(cfg, simulate=simulate, preview=preview)
    except DeviceError as exc:
        print(exc, file=sys.stderr)
        return 1
    engine.start()
    http = serve(engine, host, port)
    print(f"agent-keyboard listening on http://{host}:{port}")
    print(f"style={cfg.style.value}  fps={cfg.fps}  simulate={isinstance(engine.device, NullDevice)}")
    if cfg.path:
        print(f"config={cfg.path}")
    print("POST /event   GET /state   GET /health   POST /mcp")
    try:
        while True:
            time.sleep(0.5)
    except KeyboardInterrupt:
        print("\nstopping")
        return 0
    finally:
        http.shutdown()
        engine.stop()


def cmd_send(args, cfg) -> int:
    payload = {
        "agent": args.agent,
        "status": args.status,
        "context": args.context,
        "progress": args.progress,
        "message": args.message,
    }
    payload = {k: v for k, v in payload.items() if v is not None}
    if args.direct:
        try:
            engine = _open_engine(cfg, simulate=False)
        except DeviceError as exc:
            print(exc, file=sys.stderr)
            return 1
        engine.apply_event(AgentEvent.from_dict(payload))
        engine.start()
        time.sleep(0.2)
        engine.stop()
        return 0
    url = args.url or f"http://{DEFAULT_BRIDGE_HOST}:{DEFAULT_BRIDGE_PORT}/event"
    from urllib.request import Request, urlopen

    req = Request(url, data=json.dumps(payload).encode("utf-8"), headers={"content-type": "application/json"})
    with urlopen(req, timeout=2) as resp:  # noqa: S310
        print(resp.read().decode("utf-8"))
    return 0


def cmd_demo(cfg, simulate: bool, preview: bool, hold: float) -> int:
    try:
        engine = _open_engine(cfg, simulate=simulate, preview=preview)
    except DeviceError as exc:
        print(exc, file=sys.stderr)
        return 1
    engine.start()
    sequence = [
        ("idle", AgentStatus.IDLE, 0.0),
        ("running", AgentStatus.RUNNING, 0.35),
        ("tool", AgentStatus.TOOL, 0.55),
        ("approval", AgentStatus.APPROVAL, 0.55),
        ("done", AgentStatus.DONE, 0.0),
        ("error", AgentStatus.ERROR, 0.0),
        ("context-hot", AgentStatus.RUNNING, 0.92),
        ("idle", AgentStatus.IDLE, 0.0),
    ]
    try:
        for name, status, context in sequence:
            print(f"scene: {name}")
            engine.apply_event(
                AgentEvent(agent="codex", status=status, context=context, message=name)
            )
            time.sleep(hold)
        return 0
    except KeyboardInterrupt:
        return 0
    finally:
        engine.stop()


def cmd_idle(cfg, simulate: bool) -> int:
    try:
        engine = _open_engine(cfg, simulate=simulate)
    except DeviceError as exc:
        print(exc, file=sys.stderr)
        return 1
    engine.start()
    time.sleep(0.15)
    engine.stop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
