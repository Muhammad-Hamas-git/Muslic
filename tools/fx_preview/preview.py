"""Renders a song through müslic's ambient (slowed + reverb) effect on your
computer, using the exact Java processor the app runs on Android, so you can
tune lib/debug/ambient_tuning.dart by ear without rebuilding the app.

Needs Java (JDK 11+) and ffmpeg on PATH.

    python tools/fx_preview/preview.py song.mp3            -> song_ambient.wav
    python tools/fx_preview/preview.py song.mp3 --compare  -> also song_original.wav

Speed and pitch are applied with ffmpeg (a close stand-in for the phone's
Sonic processor; with speed == pitch they are the same "slowed" effect).
"""
import pathlib, re, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).resolve().parent
TUNING = ROOT / "lib/debug/ambient_tuning.dart"
FX = ROOT / "packages/just_audio/android/src/main/java/com/ryanheise/just_audio/FxAudioProcessor.java"


def ambient_values():
    text = TUNING.read_text()
    body = text.split("class AmbientTuning")[1].split("class FxTuning")[0]
    vals = {k: float(v) for k, v in re.findall(r"static const double (\w+) = ([0-9.]+);", body)}
    return vals


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    song = pathlib.Path(sys.argv[1]).resolve()
    v = ambient_values()
    sr = 48000
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        src = tmp / "src/com/ryanheise/just_audio"
        src.mkdir(parents=True)
        (src / "FxAudioProcessor.java").write_text(FX.read_text())
        (src / "Harness.java").write_text((HERE / "Harness.java").read_text())
        java_files = [str(p) for p in (HERE / "stubs").rglob("*.java")] + [str(p) for p in src.glob("*.java")]
        subprocess.run(["javac", "-d", str(tmp / "out"), *java_files], check=True)

        slowed = tmp / "slowed.raw"
        # Speed and pitch together = resample (like a record played slow).
        # If they differ, atempo fixes the remaining tempo difference.
        rate = v["pitch"]
        tempo = v["speed"] / v["pitch"]
        af = f"asetrate={sr}*{rate},aresample={sr}"
        if abs(tempo - 1) > 1e-3:
            af += f",atempo={tempo}"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(song),
                        "-af", af, "-f", "s16le", "-ac", "2", "-ar", str(sr), str(slowed)], check=True)
        wet = tmp / "wet.raw"
        args = [v["dry"], v["reverbWet"], v["roomSize"], v["damping"], v["width"], v["preDelayMs"],
                v["echoWet"], v["echoMs"], v["echoFeedback"], v["echoToneHz"]]
        subprocess.run(["java", "-cp", str(tmp / "out"), "com.ryanheise.just_audio.Harness",
                        str(slowed), str(wet), str(sr), *map(str, args)], check=True)
        out = song.with_name(song.stem + "_ambient.wav")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "s16le", "-ac", "2",
                        "-ar", str(sr), "-i", str(wet), str(out)], check=True)
        print("wrote", out)
        if "--compare" in sys.argv:
            orig = song.with_name(song.stem + "_original.wav")
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(song), str(orig)], check=True)
            print("wrote", orig)


if __name__ == "__main__":
    main()
