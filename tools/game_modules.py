#!/usr/bin/env python3
"""Split game run(function()) callbacks into individually editable module files."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAMES = ROOT / "games"
CATEGORY_ORDER = (
    "Combat", "Blatant", "Legit", "Utility", "World", "Render",
    "Inventory", "Minigames", "Kits", "Main", "Friends", "Targets",
)


def long_level(source: bytes, start: int) -> int | None:
    if source[start : start + 1] != b"[":
        return None
    cursor = start + 1
    while source[cursor : cursor + 1] == b"=":
        cursor += 1
    return cursor - start - 1 if source[cursor : cursor + 1] == b"[" else None


def skip_long(source: bytes, start: int, level: int) -> int:
    closer = b"]" + b"=" * level + b"]"
    end = source.find(closer, start + level + 2)
    if end < 0:
        raise ValueError("unterminated long string/comment")
    return end + len(closer)


def skip_quote(source: bytes, start: int) -> int:
    quote = source[start : start + 1]
    cursor = start + 1
    while cursor < len(source):
        if source[cursor] == 92:
            cursor += 2
        elif source[cursor : cursor + 1] == quote:
            return cursor + 1
        else:
            cursor += 1
    raise ValueError("unterminated quoted string")


def skip_lexeme(source: bytes, cursor: int) -> int | None:
    if source[cursor : cursor + 2] == b"--":
        level = long_level(source, cursor + 2)
        if level is not None:
            return skip_long(source, cursor + 2, level)
        newline = source.find(b"\n", cursor + 2)
        return len(source) if newline < 0 else newline + 1
    if source[cursor : cursor + 1] in (b"'", b'"'):
        return skip_quote(source, cursor)
    level = long_level(source, cursor)
    return skip_long(source, cursor, level) if level is not None else None


def find_run_end(source: bytes, start: int) -> int:
    cursor = start + len(b"run(")
    parens = 1
    while cursor < len(source) and parens:
        skipped = skip_lexeme(source, cursor)
        if skipped is not None:
            cursor = skipped
            continue
        if source[cursor : cursor + 1] == b"(":
            parens += 1
        elif source[cursor : cursor + 1] == b")":
            parens -= 1
        cursor += 1
    if parens:
        raise ValueError("unterminated run(function()) call")
    if not re.match(rb"run\(function\s*\([^)]*\)", source[start:cursor]):
        raise ValueError("unsupported run callback signature")
    if not re.search(rb"\bend\s*\)\s*$", source[start:cursor]):
        raise ValueError("run callback missing end)")
    return cursor


def run_blocks(source: bytes) -> list[tuple[int, int]]:
    """Return non-overlapping run(function(...)) spans, including nested calls."""
    spans: list[tuple[int, int]] = []
    cursor = 0
    while cursor < len(source):
        if source.startswith(b"--[[AEROV4_GAME_MODULE_", cursor):
            marker_end = source.find(b"]]", cursor + 23)
            if marker_end < 0:
                raise ValueError("unterminated generated module marker")
            spans.append((cursor, marker_end + 2))
            cursor = marker_end + 2
            continue
        skipped = skip_lexeme(source, cursor)
        if skipped is not None:
            cursor = skipped
            continue
        if source[cursor : cursor + 13] == b"run(function(":
            end = find_run_end(source, cursor)
            spans.append((cursor, end))
            cursor += len(b"run(")
            continue
        cursor += 1
    return spans


def direct_nested_blocks(block: bytes) -> list[tuple[int, int]]:
    spans = run_blocks(block)
    if not spans:
        raise ValueError("expected an outer feature wrapper")
    start = next((begin for begin, _ in spans if block[begin : begin + 13] == b"run(function("), None)
    if start is None:
        raise ValueError("outer feature wrapper not found")
    end = find_run_end(block, start)
    cursor = len(b"run(function(")
    while cursor < end and block[cursor : cursor + 1] != b")":
        cursor += 1
    if cursor >= end:
        raise ValueError("unterminated callback parameters")
    cursor += 1
    body_end = end - len(b"end)")
    found: list[tuple[int, int]] = []
    while cursor < body_end:
        if block[cursor : cursor + 25] == b"--[[AEROV4_NESTED_MODULE_":
            marker_end = block.find(b"]]", cursor + 23)
            if marker_end < 0:
                raise ValueError("unterminated nested module marker")
            found.append((cursor, marker_end + 2))
            cursor = marker_end + 2
            continue
        skipped = skip_lexeme(block, cursor)
        if skipped is not None:
            cursor = skipped
            continue
        if block[cursor : cursor + 13] == b"run(function(":
            nested_end = find_run_end(block, cursor)
            found.append((cursor, nested_end))
            cursor = nested_end
            continue
        cursor += 1
    return found


def metadata(block: bytes) -> tuple[str, str]:
    create = re.search(rb"vape\.Categories\.([A-Za-z_][A-Za-z0-9_]*)\s*:\s*CreateModule\s*\(\s*\{", block)
    category = create.group(1).decode("ascii") if create else ""

    if not category:
        direct = re.search(rb"vape\.([A-Za-z_][A-Za-z0-9_]*)\s*:\s*CreateModule\s*\(\s*\{", block)
        if direct:
            category = direct.group(1).decode("ascii")

    if not category:
        alias = re.search(rb"local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*vape\.Categories(?:\s+and\s+vape\.Categories)?\.([A-Za-z_][A-Za-z0-9_]*)", block)
        if alias and re.search(rb"\b" + alias.group(1) + rb"\s*:\s*CreateModule\s*\(\s*\{", block):
            category = alias.group(2).decode("ascii")
            create = re.search(rb"\b" + alias.group(1) + rb"\s*:\s*CreateModule\s*\(\s*\{", block)

    if not create:
        create = re.search(rb"\b[A-Za-z_][A-Za-z0-9_]*\s*:\s*CreateModule\s*\(\s*\{", block)

    overlay = re.search(rb"vape\s*:\s*CreateOverlay\s*\(\s*\{", block)
    if overlay:
        category = "Render"
        create = overlay

    if not category:
        category = "Setup"

    module_name = ""
    if create:
        tail = block[create.end() : create.end() + 8192]
        name = re.search(rb"\bName\s*=\s*(['\"])(.*?)\1", tail, re.DOTALL)
        if name:
            module_name = name.group(2).decode("utf-8", "replace")

    if not module_name:
        assignment = re.search(rb"local\s+([A-Za-z_][A-Za-z0-9_]*)\s*\n", block)
        if assignment:
            module_name = assignment.group(1).decode("ascii")

    if category == "Setup" and not module_name:
        setup_names = (
            (rb"entitylib\.(?:addPlayer|addEntity|getUpdateConnections|targetCheck)\s*=", "EntitySetup"),
            (rb"entitylib\.start\s*=", "EntitySetup"),
            (rb"skywars\s*=\s*setmetatable", "SkywarsSetup"),
            (rb"\bbd\s*=\s*setmetatable", "BedwarsSetup"),
            (rb"\bbedwars\s*=\s*setmetatable", "BedwarsSetup"),
            (rb"local\s+Knit\s*=", "ControllerSetup"),
        )
        for pattern, fallback in setup_names:
            if re.search(pattern, block):
                module_name = fallback
                break
    return category, module_name


def manifest_path(category: str, filename: str, index: int) -> str:
    category = safe_filename(category, "Setup")
    filename = safe_filename(filename, f"Feature{index:03d}")
    return f"{category}/{filename}.lua"


def load_order(game_dir: Path) -> list[str]:
    order_path = game_dir / "module-order.json"
    order = json.loads(order_path.read_text(encoding="utf-8"))
    if not isinstance(order, list) or any(not isinstance(item, str) for item in order):
        raise ValueError(f"invalid module order manifest: {order_path}")
    return order


def resolve_modules(game_dir: Path) -> list[Path]:
    order = load_order(game_dir)
    modules = [game_dir / relative for relative in order]
    for path in modules:
        if not path.is_file():
            raise ValueError(f"module missing from {game_dir.name}: {path.relative_to(game_dir)}")
    listed = set(order)
    discovered = set()
    for path in game_dir.rglob("*.lua"):
        if path.parent == game_dir:
            continue
        relative = path.relative_to(game_dir)
        if any(
            (game_dir / parent_relative.with_suffix(".lua")).exists()
            for parent_relative in list(relative.parents)[:-1]
        ):
            continue
        discovered.add(relative.as_posix())
    if discovered != listed:
        raise ValueError(f"module order manifest mismatch in {game_dir.name}: unlisted={sorted(discovered-listed)}, missing={sorted(listed-discovered)}")
    return modules


def migrate_module_layout() -> int:
    migrated = 0
    for game_dir in sorted(GAMES.iterdir()):
        flat = game_dir / "modules"
        if not flat.is_dir() or (game_dir / "module-order.json").exists() or game_dir.name == "8951451142":
            continue
        source_files = sorted(flat.glob("[0-9][0-9][0-9]-*.lua"))
        if not source_files:
            continue
        order: list[str] = []
        used: set[str] = set()
        moves: list[tuple[Path, Path]] = []
        for index, source in enumerate(source_files, 1):
            content = source.read_bytes()
            category, display_name = metadata(content)
            filename = safe_filename(display_name, source.stem.split("-", 1)[-1].title())
            if not display_name:
                filename = safe_filename(source.stem.split("-", 1)[-1].title(), f"Feature{index:03d}")
            relative = manifest_path(category, filename, index)
            while relative.lower() in used:
                stem = Path(relative).stem
                relative = f"{category}/{stem}{index}.lua"
            used.add(relative.lower())
            destination = game_dir / relative
            order.append(relative)
            moves.append((source, destination))
            nested = source.with_suffix("")
            if nested.is_dir():
                nested_target = destination.with_suffix("")
                moves.extend((child, nested_target / child.relative_to(nested)) for child in nested.rglob("*.lua"))
        for source, destination in moves:
            destination.parent.mkdir(parents=True, exist_ok=True)
        staging = flat / "_module_staging"
        staging.mkdir(exist_ok=True)
        staged: list[tuple[Path, Path]] = []
        for index, (source, destination) in enumerate(moves):
            if source.resolve() == destination.resolve():
                continue
            temporary = staging / f"{index:05d}.lua"
            source.rename(temporary)
            staged.append((temporary, destination))
        for temporary, destination in staged:
            temporary.rename(destination)
        staging.rmdir()
        for directory in sorted((path for path in flat.rglob("*") if path.is_dir()), key=lambda item: len(item.parts), reverse=True):
            try:
                directory.rmdir()
            except OSError:
                pass
        try:
            flat.rmdir()
        except OSError:
            pass
        (game_dir / "module-order.json").write_text(json.dumps(order, indent=2) + "\n", encoding="utf-8")
        migrated += len(order)
        print(f"organized {game_dir.name}: {len(order)} modules")
    return migrated


def safe_filename(name: str, fallback: str) -> str:
    name = re.sub(r"[^A-Za-z0-9]+", "", name)
    if not name:
        name = fallback
    return name[:100]


def top_marker(index: int) -> bytes:
    return f"--[[AEROV4_GAME_MODULE_{index:03d}]]".encode()


def nested_marker(index: int) -> bytes:
    return f"--[[AEROV4_NESTED_MODULE_{index:03d}]]".encode()


def module_source(module: Path) -> bytes:
    source = module.read_bytes()
    children = sorted(module.with_suffix("").glob("[0-9][0-9][0-9]-*.lua"))
    for index, child in enumerate(children, 1):
        token = nested_marker(index)
        if source.count(token) != 1:
            raise ValueError(f"nested placeholder mismatch in {module}")
        source = source.replace(token, module_source(child), 1)
    if b"AEROV4_NESTED_MODULE_" in source:
        raise ValueError(f"unresolved nested placeholder in {module}")
    return source


def split_games() -> int:
    count = 0
    for entry in sorted(GAMES.glob("*/main.lua")):
        source = entry.read_bytes()
        spans = run_blocks(source)
        if not spans:
            continue
        if (entry.parent / "module-order.json").exists() or (entry.parent / "template.lua").exists():
            raise FileExistsError(f"module sources already exist for {entry.parent}")
        module_root = entry.parent
        output: list[bytes] = []
        order: list[str] = []
        cursor = 0
        for index, (start, end) in enumerate(spans, 1):
            output.extend((source[cursor:start], top_marker(index)))
            block = source[start:end]
            category, name = metadata(block)
            path = manifest_path(category, name, index)
            if path in order:
                path = manifest_path(category, f"{name}{index:03d}", index)
            target = module_root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            nested = direct_nested_blocks(block)
            source_block = block
            if nested:
                pieces: list[bytes] = []
                nested_cursor = 0
                for child_index, (nested_start, nested_end) in enumerate(nested, 1):
                    child = block[nested_start:nested_end]
                    child_category, child_name = metadata(child)
                    child_path = target.with_suffix("") / f"{child_index:03d}-{safe_filename(child_name, 'NestedFeature')}.lua"
                    child_path.parent.mkdir(parents=True, exist_ok=True)
                    child_path.write_bytes(child)
                    pieces.extend((block[nested_cursor:nested_start], nested_marker(child_index)))
                    nested_cursor = nested_end
                pieces.append(block[nested_cursor:])
                source_block = b"".join(pieces)
            target.write_bytes(source_block)
            order.append(path)
            cursor = end
        output.append(source[cursor:])
        template = entry.parent / "template.lua"
        template.write_bytes(b"".join(output))
        (entry.parent / "module-order.json").write_text(json.dumps(order, indent=2) + "\n", encoding="utf-8")
        count += len(order)
        print(f"split {entry.parent.name}: {len(order)} feature modules")
    print(f"Created {count} feature modules.")
    return count


def build(check: bool = False) -> int:
    count = 0
    migrate_module_layout()
    for template in sorted(GAMES.glob("*/template.lua")):
        if template.parent.name == "8951451142":
            continue
        game_dir = template.parent
        source = template.read_bytes()
        modules = resolve_modules(game_dir)
        for index, module in enumerate(modules, 1):
            token = top_marker(index)
            if source.count(token) != 1:
                raise ValueError(f"top-level placeholder mismatch in {template}")
            source = source.replace(token, module_source(module), 1)
        if b"AEROV4_GAME_MODULE_" in source:
            raise ValueError(f"unresolved placeholder in {template}")
        entry = game_dir / "main.lua"
        if check and (not entry.exists() or entry.read_bytes() != source):
            raise ValueError(f"{entry.relative_to(ROOT)} is stale; rebuild modules")
        if not check:
            entry.write_bytes(source)
        count += len(modules)
        print(f"{'checked' if check else 'built'} {entry.relative_to(ROOT)} ({len(modules)} features)")
    print(f"Verified {count} feature modules.")
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("split", "organize", "build", "check"))
    command = parser.parse_args().command
    try:
        if command == "organize":
            migrate_module_layout()
        elif command == "split":
            split_games()
        else:
            build(check=command == "check")
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
