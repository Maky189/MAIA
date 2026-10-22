#!/usr/bin/env -S python3 -I
"""Turn PS2 / PSP ISOs into real games in Steam and Heroic, with full artwork.

  maia-games.py [games.json]

For every game in games.json this:
  1. writes a launcher  ~/Games/Launchers/<key>.sh   (PCSX2 or PPSSPP, fullscreen, NVIDIA via prime-run)
  2. downloads artwork from SteamGridDB (portrait, wide, hero, logo, icon; no API key needed)
  3. adds a Steam non-Steam shortcut with that artwork (every Steam account on this PC)
  4. adds a Heroic "sideload" entry with that artwork

Close Steam and Heroic before running it; both rewrite their files on exit.
Running it again is safe: games that are already there are skipped.
"""
import json, os, secrets, shutil, string, struct, subprocess, sys, urllib.parse, urllib.request, zlib

HOME = os.path.expanduser("~")
LAUNCHERS = os.path.join(HOME, "Games/Launchers")
ART = os.path.join(LAUNCHERS, "art")
STEAM_USERDATA = os.path.join(HOME, ".local/share/Steam/userdata")
HEROIC_LIB = os.path.join(HOME, ".config/heroic/sideload_apps/library.json")
SGDB = "https://www.steamgriddb.com/api/public"
UA = {"User-Agent": "Mozilla/5.0", "Content-Type": "application/json"}

EMULATORS = {
    "ps2": 'exec prime-run pcsx2-qt -fullscreen -nogui -- "{iso}"',
    "psp": 'exec prime-run PPSSPPSDL --fullscreen "{iso}"',
}
KINDS = {  # name: (asset_type, dimensions)
    "portrait": ("grid", ["600x900"]),
    "wide": ("grid", ["920x430", "460x215"]),
    "hero": ("hero", None),
    "logo": ("logo", None),
    "icon": ("icon", None),
}


# ---------- SteamGridDB ----------

def http_json(url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=UA), timeout=30) as r:
        return json.load(r)


def sgdb_id(game):
    if game.get("sgdb_id"):
        return game["sgdb_id"]
    res = http_json(f"{SGDB}/search/autocomplete?term={urllib.parse.quote(game['title'])}")
    hits = res.get("data") or []
    if not hits:
        raise SystemExit(f"SteamGridDB has no game called {game['title']!r}; set sgdb_id in games.json")
    return hits[0]["id"]


def fetch_art(game):
    """Download each artwork kind once; return {kind: {"file", "url"}}."""
    os.makedirs(ART, exist_ok=True)
    gid, out = None, {}
    for kind, (atype, dims) in KINDS.items():
        have = [f for f in os.listdir(ART) if f.startswith(f"{game['key']}_{kind}.")]
        meta = os.path.join(ART, f"{game['key']}_{kind}.url")
        if have and os.path.exists(meta):
            out[kind] = {"file": os.path.join(ART, have[0]), "url": open(meta).read().strip()}
            continue
        gid = gid or sgdb_id(game)
        body = {"asset_type": atype, "game_id": [gid], "order": "score_desc", "limit": 20, "static": True}
        if dims:
            body["dimensions"] = dims
        assets = [a for a in http_json(f"{SGDB}/search/assets", body)["data"]["assets"]
                  if not (a["nsfw"] or a["humor"] or a["epilepsy"] or a["is_animated"])
                  and a["mime"] in ("image/png", "image/jpeg")]
        if not assets:
            print(f"  no {kind} artwork found")
            continue
        a = assets[0]
        path = os.path.join(ART, f"{game['key']}_{kind}{'.png' if a['mime'] == 'image/png' else '.jpg'}")
        with urllib.request.urlopen(urllib.request.Request(a["url"], headers=UA), timeout=60) as r:
            open(path, "wb").write(r.read())
        open(meta, "w").write(a["url"])
        out[kind] = {"file": path, "url": a["url"]}
        print(f"  {kind}: {a['width']}x{a['height']}")
    return out


# ---------- launcher ----------

def write_launcher(game):
    os.makedirs(LAUNCHERS, exist_ok=True)
    iso = os.path.expanduser(game["iso"]).replace(HOME, "$HOME", 1)
    path = os.path.join(LAUNCHERS, f"{game['key']}.sh")
    with open(path, "w") as f:
        f.write("#!/bin/sh\n" + EMULATORS[game["system"]].format(iso=iso) + "\n")
    os.chmod(path, 0o755)
    return path


# ---------- Steam (binary shortcuts.vdf) ----------

def vdf_parse(b, i=0):
    d = {}
    while True:
        t = b[i]; i += 1
        if t == 8:
            return d, i
        e = b.index(0, i); k = b[i:e].decode(); i = e + 1
        if t == 0:
            d[k], i = vdf_parse(b, i)
        elif t == 1:
            e = b.index(0, i); d[k] = b[i:e].decode(); i = e + 1
        elif t == 2:
            d[k] = struct.unpack_from("<I", b, i)[0]; i += 4
        else:
            raise ValueError(f"unknown VDF type {t}")


def vdf_dump(d):
    out = b""
    for k, v in d.items():
        kb = k.encode() + b"\0"
        if isinstance(v, dict):
            out += b"\0" + kb + vdf_dump(v)
        elif isinstance(v, int):
            out += b"\2" + kb + struct.pack("<I", v)
        else:
            out += b"\1" + kb + v.encode() + b"\0"
    return out + b"\x08"


def add_to_steam(games):
    if not os.path.isdir(STEAM_USERDATA):
        print("Steam: not set up yet (log in once, then run this again)")
        return
    for uid in os.listdir(STEAM_USERDATA):
        cfg = os.path.join(STEAM_USERDATA, uid, "config")
        if not uid.isdigit() or uid == "0" or not os.path.isdir(cfg):
            continue
        vdf = os.path.join(cfg, "shortcuts.vdf")
        if os.path.exists(vdf):
            root, _ = vdf_parse(open(vdf, "rb").read())
            shutil.copy(vdf, vdf + ".bak")
        else:
            root = {"shortcuts": {}}
        sc = root.setdefault("shortcuts", {})
        grid = os.path.join(cfg, "grid")
        os.makedirs(grid, exist_ok=True)
        names = {v.get("AppName") for v in sc.values()}
        for game, launcher, art in games:
            exe = f'"{launcher}"'
            appid = zlib.crc32((exe + game["title"]).encode()) | 0x80000000
            for kind, suffix in (("portrait", "p"), ("wide", ""), ("hero", "_hero"), ("logo", "_logo")):
                if kind in art:
                    src = art[kind]["file"]
                    shutil.copy(src, os.path.join(grid, f"{appid}{suffix}{os.path.splitext(src)[1]}"))
            if game["title"] in names:
                continue
            sc[str(len(sc))] = {
                "appid": appid, "AppName": game["title"], "Exe": exe, "StartDir": f'"{LAUNCHERS}"',
                "icon": art.get("icon", {}).get("file", ""), "ShortcutPath": "", "LaunchOptions": "",
                "IsHidden": 0, "AllowDesktopConfig": 1, "AllowOverlay": 1, "OpenVR": 0, "Devkit": 0,
                "DevkitGameID": "", "DevkitOverrideAppID": 0, "LastPlayTime": 0, "FlatpakAppID": "",
                "tags": {}}
            print(f"Steam ({uid}): added {game['title']}")
        open(vdf, "wb").write(vdf_dump(root))


# ---------- Heroic ----------

def add_to_heroic(games):
    if os.path.exists(HEROIC_LIB):
        lib = json.load(open(HEROIC_LIB))
        shutil.copy(HEROIC_LIB, HEROIC_LIB + ".bak")
    else:
        os.makedirs(os.path.dirname(HEROIC_LIB), exist_ok=True)
        lib = {"games": []}
    have = {g.get("title") for g in lib["games"]}
    for game, launcher, art in games:
        if game["title"] in have:
            continue
        url = lambda k: art.get(k, {}).get("url", "")
        lib["games"].append({
            "runner": "sideload",
            "app_name": "".join(secrets.choice(string.ascii_letters) for _ in range(22)),
            "title": game["title"],
            "install": {"executable": launcher, "platform": "linux", "is_dlc": False},
            "folder_name": LAUNCHERS,
            "art_cover": url("hero"), "art_square": url("portrait"), "art_logo": url("logo"),
            "is_installed": True, "canRunOffline": True,
            "browserUrl": "", "customUserAgent": "", "launchFullScreen": False,
        })
        print(f"Heroic: added {game['title']}")
    json.dump(lib, open(HEROIC_LIB, "w"), indent="\t")


def running(name):
    return subprocess.run(["pgrep", "-x", name], capture_output=True).returncode == 0


def main():
    cfg = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "games.json")
    for app in ("steam", "heroic"):
        if running(app):
            raise SystemExit(f"Close {app} first, then run this again.")
    done = []
    for game in json.load(open(cfg)):
        if not os.path.exists(os.path.expanduser(game["iso"])):
            print(f"skip {game['title']}: {game['iso']} not found")
            continue
        print(game["title"])
        done.append((game, write_launcher(game), fetch_art(game)))
    if done:
        add_to_steam(done)
        add_to_heroic(done)


if __name__ == "__main__":
    main()
