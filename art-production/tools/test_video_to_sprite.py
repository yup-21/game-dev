#!/usr/bin/env python3
"""Regression tests for the offline candidate pipeline; synthetic artwork only."""
import csv
import importlib.util
import json
import shutil
import subprocess
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path

from PIL import Image, ImageDraw

SCRIPT = Path(__file__).resolve().parent / "video_to_sprite.py"
spec = importlib.util.spec_from_file_location("video_to_sprite", SCRIPT)
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)


class CandidateWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def source(self, name, step=2, transparent=True):
        path = self.root / name
        path.mkdir()
        for i in range(4):
            image = Image.new("RGBA", (100, 110),
                              (200, 100, 50, 255) if not transparent else (0, 0, 0, 0))
            if transparent:
                draw = ImageDraw.Draw(image)
                draw.rectangle((15 + i * step, 12, 45 + i * step, 89),
                               fill=(30, 55, 70, 255))
                draw.line((42 + i * step, 50, 65 + i * step, 35),
                          fill=(180, 180, 200, 255), width=3)
            image.save(path / f"frame_{i:04d}.png")
        return path

    def annotations(self, name, action, step):
        path = self.root / name
        with path.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.writer(stream)
            writer.writerow(("action", "frame", "x", "y", "reviewed", "anchor_type"))
            for i in range(4):
                writer.writerow((action, i, 30 + i * step, 89, 1, "rear_foot"))
        return path

    def pack(self, source, action, name, anchors=None, loop=False):
        target = self.root / name
        pipeline.pack(Namespace(
            frames=str(source), output=str(target), action=action,
            fps=12, loop=loop, anchors=str(anchors) if anchors else None,
            motion=None, columns=3, margin=24,
        ))
        return target

    def test_contact_alignment_margin_and_no_rescale(self):
        frames = self.source("raw", step=5)
        anchors = self.annotations("anchors.csv", "idle", 5)
        out = self.pack(frames, "idle", "candidate", anchors, loop=True)
        meta = json.loads((out / "frame_contract.json").read_text())
        atlas = Image.open(out / "atlas.png").convert("RGBA")
        cw, ch = meta["cell_size"]
        self.assertEqual(atlas.size, (3 * cw, 2 * ch))
        self.assertEqual(meta["contact_target"][1], 24 + 89 - 12)
        self.assertEqual(len(meta["frames"]), 4)
        self.assertTrue(all(f["contact_reviewed"] for f in meta["frames"]))
        for i in range(4):
            image = Image.open(out / "aligned" / f"frame_{i:04d}.png").convert("RGBA")
            bbox = image.getchannel("A").getbbox()
            self.assertGreaterEqual(bbox[0], 24)
            self.assertGreaterEqual(bbox[1], 24)
            self.assertLessEqual(bbox[2], cw - 24)
            self.assertLessEqual(bbox[3], ch - 24)
            original = Image.open(frames / f"frame_{i:04d}.png").convert("RGBA")
            original_bbox = original.getchannel("A").getbbox()
            self.assertEqual((bbox[2] - bbox[0], bbox[3] - bbox[1]),
                             (original_bbox[2] - original_bbox[0], original_bbox[3] - original_bbox[1]))
        self.assertTrue((out / "preview.gif").is_file())
        self.assertEqual(json.loads((out / "qa_report.json").read_text())["unreviewed_contacts"], [])

    def test_unreviewed_bbox_is_candidate_not_approved(self):
        out = self.pack(self.source("raw2"), "attack", "attack_candidate")
        qa = json.loads((out / "qa_report.json").read_text())
        self.assertEqual(len(qa["unreviewed_contacts"]), 4)
        self.assertEqual(len(qa["unreviewed_root_motion"]), 4)
        self.assertTrue(qa["manual_review_required"])

    def test_existing_destination_is_not_overwritten(self):
        out = self.pack(self.source("raw3"), "guard", "first")
        with self.assertRaisesRegex(ValueError, "already exists"):
            self.pack(self.root / "raw3", "guard", "first")
        self.assertTrue((out / "atlas.png").is_file())

    def test_opaque_video_frames_must_be_segmented(self):
        with self.assertRaisesRegex(ValueError, "no transparent"):
            self.pack(self.source("opaque", transparent=False), "idle", "rejected")

    def test_assemble_absolute_indices_and_partial_warning(self):
        idle_frames = self.source("idle_frames")
        attack_frames = self.source("attack_frames", step=4)
        idle = self.pack(idle_frames, "idle", "idle_candidate",
                         self.annotations("idle.csv", "idle", 2), loop=True)
        attack = self.pack(attack_frames, "attack", "attack_candidate")
        out = self.root / "combined"
        pipeline.assemble(Namespace(inputs=[str(idle), str(attack)],
                                    output=str(out), columns=4, margin=24,
                                    require_complete=False))
        data = json.loads((out / "frame_contract.json").read_text())
        self.assertEqual(data["actions"]["idle"]["frames"], [0, 1, 2, 3])
        self.assertEqual(data["actions"]["attack"]["frames"], [4, 5, 6, 7])
        self.assertIn("guard", data["missing_runtime_actions"])
        self.assertEqual(Image.open(out / "atlas.png").size[0], data["cell_size"][0] * 4)
        with self.assertRaisesRegex(ValueError, "Nine runtime actions"):
            pipeline.assemble(Namespace(inputs=[str(idle)], output=str(self.root / "not_created"),
                                        columns=4, margin=24, require_complete=True))
        self.assertFalse((self.root / "not_created").exists())

    @unittest.skipUnless(shutil.which("ffmpeg"), "FFmpeg not installed")
    def test_actual_video_extract_to_png(self):
        source = self.source("video_source")
        video = self.root / "source.mp4"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error",
                        "-framerate", "4", "-i", str(source / "frame_%04d.png"),
                        "-c:v", "mpeg4", "-pix_fmt", "yuv420p", str(video)],
                       check=True)
        output = self.root / "extracted"
        pipeline.extract(Namespace(video=str(video), output=str(output),
                                   fps=4, rembg=False))
        self.assertEqual(len(pipeline.frame_paths(output / "source_frames")), 4)

    def test_csv_requires_complete_unique_zero_based_annotations(self):
        frames = self.source("raw4")
        bad = self.root / "bad.csv"
        bad.write_text("action,frame,x,y,reviewed\nidle,0,30,89,1\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "exactly one annotation"):
            self.pack(frames, "idle", "unused", bad)
        self.assertFalse((self.root / "unused").exists())


if __name__ == "__main__":
    unittest.main()
