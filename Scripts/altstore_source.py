#!/usr/bin/env python3
"""Write the AltStore/SideStore source (apps.json format, v2) for one release.

AltStore and SideStore read the file from
https://github.com/jongsu-king/SwingLab/releases/latest/download/altstore-source.json
and offer every newer version listed there as an update.
"""
import argparse, datetime, json, os, plistlib, zipfile

ap = argparse.ArgumentParser()
ap.add_argument("--ipa", required=True)
ap.add_argument("--version", required=True)
ap.add_argument("--tag", required=True)
ap.add_argument("--repo", required=True)
ap.add_argument("--out", required=True)
a = ap.parse_args()

with zipfile.ZipFile(a.ipa) as zf:
    name = next(n for n in zf.namelist() if n.endswith(".app/Info.plist") and n.count("/") == 2)
    info = plistlib.loads(zf.read(name))
base = f"https://github.com/{a.repo}"
source = {
    "name": "SwingLab",
    "subtitle": "Swing video, launch monitor and course strategy on one iPhone",
    "identifier": "io.github.jongsu-king.swinglab",
    "sourceURL": f"{base}/releases/latest/download/altstore-source.json",
    "website": base,
    "iconURL": f"https://raw.githubusercontent.com/{a.repo}/main/SwingLab/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
    "apps": [{
        "name": "SwingLab",
        "bundleIdentifier": info["CFBundleIdentifier"],
        "developerName": "Jongsu Lim",
        "subtitle": "Native iPhone golf lab",
        "localizedDescription": "Swing video with Vision pose, an experimental 240 fps launch monitor, "
                                "a club catalog since 2000 and course strategy. Honest provenance, 12 languages.",
        "iconURL": f"https://raw.githubusercontent.com/{a.repo}/main/SwingLab/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
        "category": "sports",
        "versions": [{
            "version": a.version,
            "buildVersion": str(info.get("CFBundleVersion", "1")),
            "date": datetime.date.today().isoformat(),
            "localizedDescription": f"See {base}/releases/tag/{a.tag}",
            "downloadURL": f"{base}/releases/download/{a.tag}/{os.path.basename(a.ipa)}",
            "size": os.path.getsize(a.ipa),
            "minOSVersion": info.get("MinimumOSVersion", "17.0"),
        }],
        "appPermissions": {
            "entitlements": [],
            "privacy": {k: v for k, v in info.items() if k.startswith("NS") and k.endswith("UsageDescription")},
        },
    }],
    "news": [],
}
with open(a.out, "w", encoding="utf-8") as fh:
    json.dump(source, fh, ensure_ascii=False, indent=2)
print(f"wrote {a.out}: {a.version}, {source['apps'][0]['bundleIdentifier']}")
