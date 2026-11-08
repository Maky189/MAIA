#!/usr/bin/env python3
"""Choose artwork without repeating the last image across list and grid opens."""

import os
from pathlib import Path
import random
import tempfile


def choose_banner():
    launcher = Path(__file__).resolve().parent
    original = launcher / "banner.jpg"
    candidates = sorted(
        path for path in (launcher / "artwork").glob("*")
        if path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
    )
    if original.is_file():
        candidates.append(original)
    if not candidates:
        return original

    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    previous_file = cache / "maia-launcher" / "last-banner"
    try:
        previous = previous_file.read_text().strip()
    except (OSError, UnicodeError):
        previous = ""
    choices = [path for path in candidates if str(path) != previous]
    selected = random.choice(choices or candidates)

    # Cache failure must not prevent the launcher from opening.
    temporary = None
    try:
        previous_file.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", dir=previous_file.parent, delete=False) as output:
            temporary = Path(output.name)
            output.write(str(selected) + "\n")
        temporary.replace(previous_file)
    except OSError:
        pass
    finally:
        if temporary is not None:
            try:
                temporary.unlink(missing_ok=True)
            except OSError:
                pass
    return selected


if __name__ == "__main__":
    print(choose_banner())
