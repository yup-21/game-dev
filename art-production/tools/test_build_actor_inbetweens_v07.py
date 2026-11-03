#!/usr/bin/env python3
"""Synthetic checks for five-actor v07 optical-flow candidate generation."""
import json
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import batch_anchor_align as batch
import build_actor_inbetweens_v07 as tool


def fake_v06(folder: Path, actor: str) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    width = height = 64
    atlas = Image.new("RGBA", (6 * width, 4 * height))
    draw = ImageDraw.Draw(atlas)
    for index in range(24):
        offset = index % 4
        x, y = (index % 6) * width, (index // 6) * height
        draw.rectangle((x + 20 + offset, y + 15, x + 36 + offset, y + 39),
                       fill=(70 + index * 3, 130, 170, 255))
    filename = f"sprite_{actor}_atlas_anchor_v06.png"
    atlas.save(folder / filename)
    metadata = {
        "actor": actor, "atlas": filename, "cell_size": [width, height],
        "frames": [{
            "index": i, "reviewed": False,
            "detached_islands": int(i == 7),
        } for i in range(24)],
    }
    (folder / "frame_review.json").write_text(json.dumps(metadata), encoding="utf8")


class InbetweenTests(unittest.TestCase):
    def test_tween_preserves_alpha_and_identity_for_identical_poses(self):
        frame = np.zeros((32, 32, 4), dtype=np.uint8)
        frame[12:24, 14:20] = [25, 90, 160, 255]
        self.assertTrue(np.array_equal(tool.tween_half(frame, frame), frame))

    def test_reject_mismatched_frames(self):
        a = np.zeros((16, 16, 4), dtype=np.uint8)
        b = np.zeros((17, 16, 4), dtype=np.uint8)
        with self.assertRaises(ValueError):
            tool.tween_half(a, b)

    def test_builds_38_frames_and_retains_original_keys(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            actor = "gu_qingshuang"
            fake_v06(root / "input" / actor, actor)
            result = tool.process_actor(actor, root / "input", root / "output")
            self.assertEqual(result["total_frames"], 38)
            self.assertEqual(result["original_key_count"], 23)
            self.assertEqual(result["generated_inbetween_count"], 15)
            self.assertEqual(len(result["actions"]), 9)
            self.assertEqual(len(result["actions"]["move"]["frames"]), 8)
            self.assertEqual(len(result["actions"]["idle"]["frames"]), 1)
            self.assertTrue(all(m["min_margin"] >= 24 for m in result["frames"]))
            self.assertTrue(all(not m["reviewed_contact"] for m in result["frames"]))
            self.assertTrue(any(m.get("manual_redraw_priority") for m in result["frames"]))
            output = root / "output" / actor
            self.assertEqual(len(list(output.glob("preview_*_v07.gif"))), 9)
            with Image.open(output / result["atlas"]) as atlas:
                self.assertEqual(atlas.mode, "RGBA")
                self.assertEqual(atlas.size, (8 * 128, 5 * 128))
                # The very first idle keyframe remains unchanged, apart from 32px padding.
                old = Image.open(root / "input" / actor /
                                 f"sprite_{actor}_atlas_anchor_v06.png").convert("RGBA")
                key_index = batch.ACTIONS["idle"][0]
                old_region = old.crop((key_index * 64, 0, (key_index + 1) * 64, 64))
                self.assertEqual(
                    atlas.crop((32, 32, 96, 96)).tobytes(),
                    old_region.tobytes(),
                )
            self.assertTrue((output / "frame_review_v07.json").exists())

    def test_nonloop_does_not_add_last_to_first_tween(self):
        old = np.zeros((128, 128, 4), dtype=np.uint8)
        old[40:70, 40:70] = (60, 80, 100, 255)
        indexed = {index: old.copy() for index in (6, 7, 8)}
        records = {i: {"reviewed": False, "detached_islands": 0}
                   for i in indexed}
        frames, meta = tool.compose_action("attack", [6, 7, 8], indexed, records)
        self.assertEqual(len(frames), 5)
        self.assertEqual(meta[-1]["source_index"], 8)
        self.assertEqual(sum(m["kind"] == "optical_flow_candidate" for m in meta), 2)


if __name__ == "__main__":
    unittest.main()
