#!/usr/bin/env python3
"""Render self-contained Manim scenes with local narration and scene subtitles."""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import keyword
import logging as lg
import math
import os
import shutil
import subprocess as sp
import sys
import tempfile
import unittest as ut
from dataclasses import dataclass
from pathlib import Path
from unittest import mock

MINIMUM_PYTHON = (3, 11)
FPS = 30
TOOLS = ("manim", "piper", "ffmpeg", "ffprobe", "sed")
LOG = lg.getLogger(__name__)


class RenderError(Exception):
    pass


@dataclass(frozen=True)
class Scene:
    name: str
    narration: str


@dataclass(frozen=True)
class Manifest:
    source: Path
    scenes: tuple[Scene, ...]
    language: str


def load_manifest(path: Path) -> Manifest:
    document = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(document, dict):
        raise RenderError("Manifest must be a JSON object")
    source_name = document.get("source")
    rows = document.get("scenes")
    language = document.get("language", "nl")
    if not isinstance(source_name, str) or Path(source_name).is_absolute():
        raise RenderError("source must be a relative Python file path")
    source = (path.parent / source_name).resolve()
    if source.suffix != ".py" or not source.is_file():
        raise RenderError(f"Missing Python scene source: {source}")
    if not isinstance(language, str) or not language.strip():
        raise RenderError("language must be a nonempty language code")
    if not isinstance(rows, list) or not rows:
        raise RenderError("scenes must be a nonempty list")
    scenes = []
    for row in rows:
        if not isinstance(row, dict):
            raise RenderError("Each scene must be an object")
        name, narration = row.get("scene"), row.get("narration")
        if (
            not isinstance(name, str)
            or not name.isidentifier()
            or keyword.iskeyword(name)
        ):
            raise RenderError("scene must be a Python class name")
        if not isinstance(narration, str) or not narration.strip():
            raise RenderError(f"Scene {name} needs nonempty narration")
        scenes.append(Scene(name, narration.strip()))
    return Manifest(source, tuple(scenes), language.strip())


def language_code(language: str) -> str:
    return language.lower().replace("-", "_").split("_", 1)[0]


def readiness(model: Path, rules: Path, language: str | None = None) -> None:
    missing = [name for name in TOOLS if shutil.which(name) is None]
    if missing:
        raise RenderError(
            f"Missing tools: {', '.join(missing)}. Run through the Nix package."
        )
    for path in (model, Path(f"{model}.json"), rules):
        if not path.is_file() or not os.access(path, os.R_OK):
            raise RenderError(f"Missing or unreadable speech resource: {path}")
    config = json.loads(Path(f"{model}.json").read_text(encoding="utf-8"))
    if not isinstance(config, dict) or not isinstance(config.get("language"), dict):
        raise RenderError("Voice configuration needs language.code")
    voice = config["language"].get("code")
    if not isinstance(voice, str) or not voice:
        raise RenderError("Voice configuration needs language.code")
    if language is not None and language_code(voice) != language_code(language):
        raise RenderError(
            f"Voice language {voice} differs from {language}; select a matching --model"
        )


def capture(command: list[str], text: str | None = None) -> str:
    result = sp.run(  # noqa: S603 -- Callers construct argument vectors, never shell commands.
        command, input=text, text=True, capture_output=True, check=False, timeout=30
    )
    if result.returncode:
        raise RenderError(f"{command[0]} failed: {result.stderr.strip()}")
    return result.stdout


def run_logged(
    command: list[str], log: Path, *, cwd: Path, text: str | None = None
) -> None:
    LOG.info("Running %s; log=%s", command[0], log)
    with log.open("w", encoding="utf-8") as stream:
        result = sp.run(  # noqa: S603 -- Trusted scene code is executed only by the render command.
            command,
            cwd=cwd,
            input=text,
            text=True,
            stdout=stream,
            stderr=sp.STDOUT,
            check=False,
            timeout=21600,
        )
    if result.returncode:
        raise RenderError(f"{command[0]} exited {result.returncode}; see {log}")


def duration(path: Path) -> float:
    value = float(
        capture(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(path),
            ]
        ).strip()
    )
    if not math.isfinite(value) or value <= 0:
        raise RenderError(f"Invalid media duration: {path}")
    return value


def padded_duration(video: float, audio: float) -> float:
    if not all(math.isfinite(value) and value > 0 for value in (video, audio)):
        raise RenderError("Media durations must be positive and finite")
    return math.ceil(max(video, audio) * FPS) / FPS


def timestamp(seconds: float) -> str:
    milliseconds = round(seconds * 1000)
    seconds, milliseconds = divmod(milliseconds, 1000)
    minutes, seconds = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    return f"{hours:02}:{minutes:02}:{seconds:02},{milliseconds:03}"


def subtitles(scenes: tuple[Scene, ...], lengths: list[float]) -> str:
    offset = 0.0
    blocks = []
    for index, (scene, length) in enumerate(zip(scenes, lengths, strict=True), 1):
        end = offset + length
        # Blank lines delimit SRT cues; retain words without introducing extra cues.
        text = "\n".join(
            line.strip() for line in scene.narration.splitlines() if line.strip()
        )
        blocks.append(f"{index}\n{timestamp(offset)} --> {timestamp(end)}\n{text}\n")
        offset = end
    return "\n".join(blocks)


def verify_movie(path: Path) -> None:
    document = json.loads(
        capture(["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(path)])
    )
    streams = document.get("streams", [])
    videos = [stream for stream in streams if stream.get("codec_type") == "video"]
    audios = [stream for stream in streams if stream.get("codec_type") == "audio"]
    if len(videos) != 1 or not audios:
        raise RenderError("Final movie must contain one video stream and narration")
    video = videos[0]
    if (
        video.get("codec_name"),
        video.get("width"),
        video.get("height"),
        video.get("r_frame_rate"),
    ) != ("h264", 1920, 1080, "30/1") or audios[0].get("codec_name") != "aac":
        raise RenderError("Final movie does not match H.264 1080p30 with AAC narration")


def render(
    manifest: Manifest, output: Path, model: Path, rules: Path, *, dry_run: bool = False
) -> Path:
    if output.exists() or output.is_symlink():
        raise RenderError(f"Output already exists; choose a new directory: {output}")
    readiness(model, rules, manifest.language)
    if dry_run:
        print(f"Would render {len(manifest.scenes)} scenes into {output}")
        return output / "explanation.mp4"
    output.mkdir(parents=True, exist_ok=False)
    sources = output / "sources"
    sources.mkdir()
    source = sources / "scenes.py"
    shutil.copyfile(manifest.source, source)
    (sources / "manifest.json").write_text(
        json.dumps(
            {
                "source": "scenes.py",
                "language": manifest.language,
                "scenes": [
                    {"scene": scene.name, "narration": scene.narration}
                    for scene in manifest.scenes
                ],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    work = output / "work"
    work.mkdir()
    lengths = []
    parts = []
    for index, scene in enumerate(manifest.scenes, 1):
        folder = work / f"scene-{index:03}"
        folder.mkdir()
        audio = folder / "narration.wav"
        speech = scene.narration
        if language_code(manifest.language) == "nl":
            speech = capture(["sed", "-f", str(rules)], speech)
        run_logged(
            [
                "piper",
                "--model",
                str(model),
                "--config",
                f"{model}.json",
                "--output-file",
                str(audio),
            ],
            folder / "piper.log",
            cwd=folder,
            text=speech + "\n",
        )
        media = folder / "media"
        run_logged(
            [
                "manim",
                "render",
                "--silent",
                "--progress_bar=none",
                "--seed=0",
                "--renderer=cairo",
                "--resolution",
                "1920,1080",
                "--fps",
                str(FPS),
                "--format=mp4",
                "--disable_caching",
                "--media_dir",
                str(media),
                "--output_file",
                "scene",
                str(source),
                scene.name,
            ],
            folder / "manim.log",
            cwd=sources,
        )
        movies = list(media.rglob("scene.mp4"))
        if len(movies) != 1:
            raise RenderError(f"Expected one Manim movie; inspect {media}")
        silent = movies[0]
        video_length, audio_length = duration(silent), duration(audio)
        length = padded_duration(video_length, audio_length)
        part = folder / "segment.mp4"
        run_logged(
            [
                "ffmpeg",
                "-nostdin",
                "-v",
                "warning",
                "-i",
                str(silent),
                "-i",
                str(audio),
                "-map",
                "0:v:0",
                "-map",
                "1:a:0",
                "-vf",
                f"tpad=stop_mode=clone:stop_duration={length - video_length:.9f}",
                "-af",
                "apad",
                "-t",
                f"{length:.9f}",
                "-r",
                str(FPS),
                "-s",
                "1920x1080",
                "-c:v",
                "libx264",
                "-preset",
                "medium",
                "-crf",
                "20",
                "-pix_fmt",
                "yuv420p",
                "-c:a",
                "aac",
                "-ar",
                "48000",
                "-ac",
                "2",
                str(part),
            ],
            folder / "ffmpeg.log",
            cwd=folder,
        )
        lengths.append(duration(part))
        parts.append(f"file {folder.name}/segment.mp4\n")
    (output / "explanation.srt").write_text(
        subtitles(manifest.scenes, lengths), encoding="utf-8"
    )
    (output / "transcript.txt").write_text(
        "\n\n".join(scene.narration for scene in manifest.scenes) + "\n",
        encoding="utf-8",
    )
    concat = work / "concat.txt"
    concat.write_text("".join(parts), encoding="utf-8")
    partial = output / "explanation.partial.mp4"
    run_logged(
        [
            "ffmpeg",
            "-nostdin",
            "-v",
            "warning",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(concat),
            "-c",
            "copy",
            "-movflags",
            "+faststart",
            str(partial),
        ],
        work / "concat.log",
        cwd=work,
    )
    verify_movie(partial)
    movie = output / "explanation.mp4"
    partial.rename(movie)
    return movie


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    commands = result.add_subparsers(dest="command", required=True)
    task = commands.add_parser(
        "render", help="Render trusted Python scenes into a new output directory"
    )
    task.add_argument("manifest", type=Path)
    task.add_argument("--output", type=Path, required=True)
    task.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate inputs and preview without writing",
    )
    check = commands.add_parser(
        "check", help="Check local tools, model and pronunciation rules"
    )
    for command in (task, check):
        command.add_argument(
            "--model",
            type=Path,
            default=Path(
                os.environ.get(
                    "VIDEO_EXPLAINER_MODEL",
                    str(
                        Path.home() / ".local/share/piper-voices/nl_NL-pim-medium.onnx"
                    ),
                )
            ),
        )
    commands.add_parser(
        "unit-test", help="Run isolated tests without rendering or network access"
    )
    return result


def main(argv: list[str] | None = None) -> int:
    if sys.version_info < MINIMUM_PYTHON:
        print("Error: Python 3.11 or newer is required", file=sys.stderr)
        return 1
    args = parser().parse_args(argv)
    if args.command == "unit-test":
        return (
            0
            if ut.TextTestRunner(stream=sys.stdout)
            .run(ut.defaultTestLoader.loadTestsFromTestCase(RenderTests))
            .wasSuccessful()
            else 1
        )
    lg.basicConfig(level=lg.INFO, format="%(levelname)s %(message)s")
    rules = Path(
        os.environ.get(
            "VIDEO_EXPLAINER_RULES", str(Path.home() / ".config/say/piper.sed")
        )
    ).resolve()
    try:
        # Keep model/config siblings together when Home Manager links both files.
        model = args.model.absolute()
        if args.command == "check":
            readiness(model, rules)
            print("ok")
        else:
            movie = render(
                load_manifest(args.manifest.resolve()),
                args.output.absolute(),
                model,
                rules,
                dry_run=args.dry_run,
            )
            if not args.dry_run:
                print(movie)
    except (RenderError, OSError, ValueError, sp.SubprocessError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


class RenderTests(ut.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="video test ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source with spaces.py"
        self.source.write_text("# self-contained scenes\n", encoding="utf-8")
        self.manifest = self.root / "manifest.json"
        self.document = {
            "source": self.source.name,
            "scenes": [{"scene": "Intro", "narration": "Dit is nixcfg."}],
        }
        self.model = self.root / "model.onnx"
        self.model.touch()
        Path(f"{self.model}.json").write_text(
            '{"language":{"code":"nl_NL"}}', encoding="utf-8"
        )
        self.rules = self.root / "rules.sed"
        self.rules.write_text("", encoding="utf-8")

    def load(self, document: object) -> Manifest:
        self.manifest.write_text(json.dumps(document), encoding="utf-8")
        return load_manifest(self.manifest)

    def test_manifest_paths_and_original_narration(self) -> None:
        manifest = self.load(self.document)
        self.assertEqual(manifest.source, self.source)
        self.assertEqual(manifest.scenes[0].narration, "Dit is nixcfg.")

    def test_invalid_manifests(self) -> None:
        for document in (
            [],
            {},
            {**self.document, "source": "/absolute.py"},
            {**self.document, "source": "missing.py"},
            {**self.document, "scenes": []},
            {**self.document, "scenes": [None]},
            {**self.document, "scenes": [{"scene": "class", "narration": "x"}]},
            {**self.document, "scenes": [{"scene": "Intro", "narration": " "}]},
        ):
            with self.subTest(document=document), self.assertRaises(RenderError):
                self.load(document)

    def test_voice_and_tools(self) -> None:
        with mock.patch.object(shutil, "which", return_value="/bin/tool"):
            readiness(self.model, self.rules, "nl")
            with self.assertRaisesRegex(RenderError, "differs"):
                readiness(self.model, self.rules, "en")
            with self.assertRaisesRegex(RenderError, "Missing or unreadable"):
                readiness(self.root / "absent", self.rules)
        with (
            mock.patch.object(shutil, "which", return_value=None),
            self.assertRaisesRegex(RenderError, "Missing tools"),
        ):
            readiness(self.model, self.rules)

    def test_padding_never_truncates(self) -> None:
        for video, audio in ((2, 5.01), (8.12, 3), (2.01, 2.02)):
            result = padded_duration(video, audio)
            self.assertGreaterEqual(result, max(video, audio))
            self.assertLess(result - max(video, audio), 1 / FPS + 1e-9)
        with self.assertRaises(RenderError):
            padded_duration(float("nan"), 1)

    def test_subtitles_keep_text_and_timeline(self) -> None:
        scenes = (Scene("One", "nixcfg\n\nscoped"), Scene("Two", "Volgende scène"))
        text = subtitles(scenes, [1.9996, 2.5])
        self.assertIn("00:00:00,000 --> 00:00:02,000\nnixcfg\nscoped", text)
        self.assertIn("00:00:02,000 --> 00:00:04,500", text)
        self.assertEqual(timestamp(3600.001), "01:00:00,001")

    def test_dry_run_and_existing_output(self) -> None:
        manifest = self.load(self.document)
        output = self.root / "new output"
        with (
            mock.patch.object(shutil, "which", return_value="/bin/tool"),
            mock.patch("builtins.print"),
        ):
            render(manifest, output, self.model, self.rules, dry_run=True)
        self.assertFalse(output.exists())
        output.mkdir()
        with self.assertRaisesRegex(RenderError, "already exists"):
            render(manifest, output, self.model, self.rules)

    def test_process_failure_preserves_log_and_sources(self) -> None:
        manifest = self.load(self.document)
        output = self.root / "failed output"
        failure = sp.CompletedProcess(["piper"], 7)
        with (
            mock.patch.object(shutil, "which", return_value="/bin/tool"),
            mock.patch(f"{__name__}.capture", return_value="Spraak"),
            mock.patch.object(sp, "run", return_value=failure),
            self.assertRaisesRegex(RenderError, "see.*piper.log"),
        ):
            render(manifest, output, self.model, self.rules)
        self.assertTrue((output / "sources/scenes.py").is_file())
        self.assertTrue((output / "work/scene-001/piper.log").is_file())
        self.assertFalse((output / "explanation.mp4").exists())

    def test_check_stdout_and_errors(self) -> None:
        stdout, stderr = io.StringIO(), io.StringIO()
        settings = {"VIDEO_EXPLAINER_RULES": str(self.rules)}
        with (
            mock.patch.dict(os.environ, settings),
            mock.patch.object(shutil, "which", return_value="/bin/tool"),
            contextlib.redirect_stdout(stdout),
            contextlib.redirect_stderr(stderr),
        ):
            self.assertEqual(main(["check", "--model", str(self.model)]), 0)
        self.assertEqual(stdout.getvalue(), "ok\n")
        self.assertEqual(stderr.getvalue(), "")
        stdout, stderr = io.StringIO(), io.StringIO()
        with (
            mock.patch.object(shutil, "which", return_value=None),
            contextlib.redirect_stdout(stdout),
            contextlib.redirect_stderr(stderr),
        ):
            self.assertEqual(main(["check"]), 1)
        self.assertEqual(stdout.getvalue(), "")
        self.assertIn("Missing tools", stderr.getvalue())

    def test_symlinked_voice_pair(self) -> None:
        folder = self.root / "linked voice"
        folder.mkdir()
        model = folder / "pim.onnx"
        model.symlink_to(self.model)
        Path(f"{model}.json").symlink_to(Path(f"{self.model}.json"))
        with (
            mock.patch.dict(os.environ, {"VIDEO_EXPLAINER_RULES": str(self.rules)}),
            mock.patch.object(shutil, "which", return_value="/bin/tool"),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(main(["check", "--model", str(model)]), 0)

    def test_existing_dangling_output_symlink(self) -> None:
        self.load(self.document)
        output = self.root / "existing link"
        missing = self.root / "missing target"
        output.symlink_to(missing, target_is_directory=True)
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(
                main(["render", str(self.manifest), "--output", str(output)]), 1
            )
        self.assertTrue(output.is_symlink())
        self.assertFalse(missing.exists())

    def test_invalid_voice_configuration(self) -> None:
        for config in ([], {"language": []}, {"language": {"code": None}}):
            Path(f"{self.model}.json").write_text(json.dumps(config), encoding="utf-8")
            with (
                mock.patch.object(shutil, "which", return_value="/bin/tool"),
                self.assertRaisesRegex(RenderError, "language.code"),
            ):
                readiness(self.model, self.rules)

    def test_final_movie_streams(self) -> None:
        video = {
            "codec_type": "video",
            "codec_name": "h264",
            "width": 1920,
            "height": 1080,
            "r_frame_rate": "30/1",
        }
        audio = {"codec_type": "audio", "codec_name": "aac"}
        with mock.patch(
            f"{__name__}.capture", return_value=json.dumps({"streams": [video, audio]})
        ):
            verify_movie(self.root / "movie.mp4")
        for streams in ([video], [{**video, "width": 640}, audio]):
            with (
                mock.patch(
                    f"{__name__}.capture", return_value=json.dumps({"streams": streams})
                ),
                self.assertRaises(RenderError),
            ):
                verify_movie(self.root / "bad.mp4")


if __name__ == "__main__":
    sys.exit(main())
