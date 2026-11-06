#!/usr/bin/env python3
"""Regression for candidate-only preview assets vs in-use art inventory."""

from inventory_assets import current_bindings, validate


def main() -> None:
    bindings = current_bindings()
    official = "res://assets/imported/scenes/rainy_bridge/background.png"
    assert official in bindings, "official map layer must remain inventoried"

    for scene_id in ("temple_hall", "mountain_road"):
        for layer in ("background", "ground", "foreground"):
            candidate = f"res://assets/candidates/prologue/{scene_id}/{layer}.webp"
            assert candidate not in bindings, f"candidate preview counted as in-use: {candidate}"

    assert not validate(bindings), "in-use references and mirrors must still match"

    # Keep the gate strict for any accidental candidate path in a real binding.
    wrong = dict(bindings)
    wrong["res://assets/candidates/prologue/temple_hall/background.webp"] = [
        "data/native/scene_art/example.tres"]
    errors = validate(wrong)
    assert any("Bound artwork must be under assets/imported/" in error for error in errors)
    print("ART_INVENTORY_CANDIDATES_PASS")


if __name__ == "__main__":
    main()
