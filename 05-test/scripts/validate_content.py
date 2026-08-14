import json
import sys
from pathlib import Path

def fail(msg):
    print("ERROR:", msg)
    return 1

def validate(data):
    errors = []

    categories = data.get("categories", [])
    drawings = data.get("drawings", [])

    category_ids = [c.get("id") for c in categories]
    drawing_ids = [d.get("id") for d in drawings]

    if len(category_ids) != len(set(category_ids)):
        errors.append("Duplicate category IDs")

    if len(drawing_ids) != len(set(drawing_ids)):
        errors.append("Duplicate drawing IDs")

    valid_categories = set(category_ids)

    for d in drawings:
        did = d.get("id", "<missing-id>")

        if d.get("categoryId") not in valid_categories:
            errors.append(f"{did}: invalid categoryId")

        if not d.get("thumbnail"):
            errors.append(f"{did}: missing thumbnail")

        if not d.get("coloringAsset"):
            errors.append(f"{did}: missing coloringAsset")

        if not isinstance(d.get("isPremium"), bool):
            errors.append(f"{did}: isPremium must be boolean")

    return errors

def main():
    if len(sys.argv) != 2:
        print("Usage: python validate_content.py manifest.json")
        return 2

    path = Path(sys.argv[1])
    data = json.loads(path.read_text(encoding="utf-8"))

    errors = validate(data)

    if errors:
        print("VALIDATION FAILED")
        for e in errors:
            print("-", e)
        return 1

    print("VALIDATION PASSED")
    print(f"Categories: {len(data.get('categories', []))}")
    print(f"Drawings: {len(data.get('drawings', []))}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
