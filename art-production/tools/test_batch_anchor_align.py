#!/usr/bin/env python3
"""Synthetic regression checks for anchor-only sprite repacking; no game files changed."""
import csv
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image, ImageDraw

import batch_anchor_align as tool


def synthetic_atlas(touch_edge=False):
    atlas = Image.new("RGBA", (6 * 64, 4 * 64))
    marks = []
    draw = ImageDraw.Draw(atlas)
    for index in range(24):
        dx = (index % 3) * 4
        dy = (index % 4) * 3
        left, top = 8 + dx, 7 + dy
        if touch_edge and index == 7:
            left = 0
        right, bottom = left + 20, top + 35
        col, row = index % 6, index // 6
        draw.rectangle((col * 64 + left, row * 64 + top,
                        col * 64 + right - 1, row * 64 + bottom - 1),
                       fill=(index * 9 % 255, 44, 135, 255))
        marks.append((left + 5, bottom - 1))
    return atlas, marks


class AlignTests(unittest.TestCase):
    def test_contract_excludes_alternate_idle_view(self):
        self.assertEqual(tool.action_for(0), ("unused", 0))
        self.assertEqual(tool.ACTIONS["idle"], (1,))
        self.assertEqual(len(tool.ACTIONS), 9)
        self.assertEqual(sum(map(len, tool.ACTIONS.values())), 23)

    def test_align_and_preserve_original_pixels(self):
        atlas, marks = synthetic_atlas()
        frames = tool.split_frames(atlas)
        anchors = {i: tool.Anchor(*marks[i], reviewed=True) for i in range(24)}
        items = tool.collect(frames, anchors)
        packed, (width, height), reports = tool.repack(frames, items, 24)
        self.assertEqual(packed.size, (width * 6, height * 4))
        self.assertTrue(all(r["min_margin"] >= 24 for r in reports))
        self.assertTrue(all(r["reviewed"] for r in reports))
        self.assertEqual(len(set(tuple(r["anchor_target"]) for r in reports)), 1)
        # A colored pixel near the source's anchor lands in the exact destination.
        x, y = reports[8]["anchor_target"]
        color = frames[8].getpixel((marks[8][0], marks[8][1]))
        self.assertEqual(packed.getpixel(((8 % 6) * width + x,
                                          (8 // 6) * height + y)), color)

    def test_explicit_root_motion_and_source_edge_warning(self):
        atlas, marks = synthetic_atlas(touch_edge=True)
        frames = tool.split_frames(atlas)
        anchors = {i: tool.Anchor(*marks[i], reviewed=True) for i in range(24)}
        anchors[7] = tool.Anchor(*marks[7], reviewed=True, root_dx=8)
        items = tool.collect(frames, anchors)
        _, _, reports = tool.repack(frames, items, 24)
        self.assertEqual(reports[7]["anchor_target"][0] -
                         reports[6]["anchor_target"][0], 8)
        self.assertTrue(reports[7]["source_edge_warning"])

    def test_detached_fragment_warning_is_non_destructive(self):
        frame = Image.new("RGBA", (100, 100))
        draw = ImageDraw.Draw(frame)
        draw.rectangle((7, 30, 38, 84), fill=(80, 70, 65, 255))
        draw.rectangle((68, 3, 87, 20), fill=(80, 70, 65, 255))
        original = frame.tobytes()
        self.assertGreaterEqual(tool.detached_alpha_islands(frame), 1)
        self.assertEqual(frame.tobytes(), original)

    def test_reject_unreviewed_root_motion(self):
        atlas, marks = synthetic_atlas()
        frames = tool.split_frames(atlas)
        annotations = {7: tool.Anchor(*marks[7], root_dx=10)}
        with self.assertRaises(ValueError):
            tool.collect(frames, annotations)

    def test_can_generate_all_nine_action_gifs_without_runtime_change(self):
        atlas, marks = synthetic_atlas()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            original = path / "source.png"
            atlas.save(original)
            with patch.object(tool, "source_path", return_value=original):
                report = tool.process_actor(
                    "black_blade", path / "candidate", None, 24, False, True
                )
            self.assertEqual(len(report["unreviewed_frames"]), 23)
            self.assertEqual(len(report["actions"]), 9)
            result = path / "candidate/black_blade"
            self.assertTrue((result / "frame_review.json").exists())
            self.assertTrue((result / "black_blade.csv").exists())
            with (result / "black_blade.csv").open(encoding="utf-8", newline="") as stream:
                rows = list(csv.DictReader(stream))
            # Exported CSV must be readable by the same script and by PR #103's
            # anchor editor: local action frame, plus absolute atlas_index.
            self.assertEqual(len(rows), 23)
            self.assertEqual((rows[0]["action"], rows[0]["frame"],
                              rows[0]["atlas_index"]), ("idle", "0", "1"))
            self.assertEqual((rows[-1]["action"], rows[-1]["frame"],
                              rows[-1]["atlas_index"]), ("defeat", "1", "23"))
            restored = tool.read_annotations(path / "candidate", "black_blade")
            self.assertEqual(len(restored), 23)
            self.assertFalse(restored[1].reviewed)
            with patch.object(tool, "source_path", return_value=original):
                tool.process_actor("black_blade", path / "round_trip",
                                   path / "candidate", 24, False, False)
            self.assertEqual(len(list(result.glob("preview_*.gif"))), 9)
            with Image.open(result / "sprite_black_blade_atlas_anchor_v06.png") as packed:
                self.assertEqual(packed.mode, "RGBA")
                self.assertTrue(packed.width > atlas.width)
            with self.assertRaises(ValueError):
                with patch.object(tool, "source_path", return_value=original):
                    tool.process_actor("black_blade", path / "no", None, 24, True, False)


if __name__ == "__main__":
    unittest.main()
