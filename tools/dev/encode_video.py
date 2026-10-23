"""Turn a film the game wrote (AVI from --write-movie) into an MP4 a phone plays.

Nearest-neighbour scaled to 960x540 so pixel art stays sharp, H.264 + AAC,
faststart. Phones need MP4 with playsinline on the page, not WebP.

usage: uv run --with imageio-ffmpeg python tools/dev/encode_video.py IN.avi OUT.mp4 [START_SECONDS]
"""
import subprocess
import sys

import imageio_ffmpeg


def streams(ff, path):
    r = subprocess.run([ff, "-i", path], capture_output=True, text=True)
    return [line.strip() for line in r.stderr.splitlines() if "Stream" in line or "Duration" in line]


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    src, out = sys.argv[1], sys.argv[2]
    start = sys.argv[3] if len(sys.argv) > 3 else "0"
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    print(streams(ff, src))
    subprocess.run([ff, "-y", "-loglevel", "error", "-ss", start, "-i", src,
                    "-vf", "scale=960:540:flags=neighbor", "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-crf", "16", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", out], check=True)
    print(streams(ff, out))


if __name__ == "__main__":
    main()
