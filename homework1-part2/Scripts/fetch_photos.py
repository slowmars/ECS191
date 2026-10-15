#!/usr/bin/env python3
"""Downloads the recipe photos listed in Scripts/photos.json into the app's asset catalog.

Each recipe's photo was picked by hand from TheMealDB or Wikimedia Commons (free licenses).
This script:
  * downloads each photo (politely, with pauses),
  * resizes it to at most 900 px and re-encodes it as JPEG,
  * writes PlatePlan/Assets.xcassets/Photos/photo-<recipe id>.imageset,
  * writes PlatePlan/Resources/photo-credits.json, which the app shows on its Photo Credits screen
    (Creative Commons licenses require crediting the photographer).

Run:  python3 Scripts/fetch_photos.py
"""
import json, subprocess, tempfile, time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "Scripts" / "photos.json"
CATALOG = ROOT / "PlatePlan" / "Assets.xcassets" / "Photos"
CREDITS = ROOT / "PlatePlan" / "Resources" / "photo-credits.json"
UA = "PlatePlanClassProject/1.0 (educational iOS app prototype)"
FREE = ("CC", "Public domain", "GFDL", "TheMealDB")


def get(url):
    for attempt in range(5):
        r = subprocess.run(["curl", "-sL", "--max-time", "60", "-A", UA, "-w", "\n%{http_code}", url], capture_output=True)
        body, _, code = r.stdout.rpartition(b"\n")
        if code == b"200" and body:
            return body
        time.sleep(10 * (attempt + 1))
    raise RuntimeError(f"Couldn't download {url}")


def image_url(photo):
    if photo["source"] == "TheMealDB":
        meal = json.loads(get(f"https://www.themealdb.com/api/json/v1/1/lookup.php?i={photo['mealId']}"))["meals"][0]
        return meal["strMealThumb"]
    return photo["url"]


def main():
    manifest = json.loads(MANIFEST.read_text())
    CATALOG.mkdir(parents=True, exist_ok=True)
    (CATALOG / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
    credits = []
    for recipe_id, photo in manifest.items():
        assert photo["license"].startswith(FREE), f"{recipe_id}: license {photo['license']} isn't free to reuse"
        imageset = CATALOG / f"photo-{recipe_id}.imageset"
        jpg = imageset / f"{recipe_id}.jpg"
        if not jpg.exists():
            imageset.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(suffix=".img") as raw:
                raw.write(get(image_url(photo)))
                raw.flush()
                subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "80", "-Z", "900",
                                raw.name, "--out", str(jpg)], check=True, capture_output=True)
            time.sleep(1)
        (imageset / "Contents.json").write_text(json.dumps({
            "images": [{"idiom": "universal", "filename": jpg.name}],
            "info": {"author": "xcode", "version": 1},
        }, indent=2))
        credits.append({"recipeId": recipe_id, "title": photo["title"], "author": photo["author"],
                        "license": photo["license"], "source": photo["source"], "page": photo["page"]})
        print(f"✓ {recipe_id}")
    CREDITS.write_text(json.dumps(credits, indent=1, ensure_ascii=False) + "\n")
    print(f"{len(credits)} photos, credits in {CREDITS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
