"""List the artist and title of every SSRG chart (.seq) in a folder as a CSV.

Usage:
    python seq_to_csv.py <folder> [output.csv]

A .seq file is an SSRG chart (the same layout SYNK's SSRG import reads). It holds no title or
artist fields; the only name in it is the song's audio file, e.g. "FTISLAND_Severely.ogg",
written as <artist>_<title>. The artist is taken as the part before the first underscore and the
title as the rest, so artists whose own names contain an underscore need fixing by hand; the
"audio" column keeps the original name for that.

Also written: song id and key count from the file name (1001_4.seq = song 1001, 4 keys),
BPM, song length in seconds and note count from the chart header.
"""
import csv
import os
import re
import struct
import sys

RECORD = 24


def read(path):
    with open(path, "rb") as handle:
        data = handle.read()
    info = {"audio": "", "artist": "", "title": "", "bpm": "", "length": "", "notes": ""}
    if len(data) >= 0x58:
        count = struct.unpack_from("<I", data, 0x2C)[0]
        header = len(data) - count * RECORD
        if 0x58 <= header <= len(data):
            info["notes"] = count
            info["length"] = round(struct.unpack_from("<d", data, 0x08)[0], 2)
            info["bpm"] = round(struct.unpack_from("<d", data, 0x50)[0], 2)
        else:
            header = len(data)
        found = re.search(rb"([A-Za-z0-9_\-.()' ]+?)\.ogg", data[:header])
        if found:
            name = found.group(1).decode("ascii", "ignore").strip()
            info["audio"] = name + ".ogg"
            artist, _, title = name.partition("_")
            if not title:
                artist, title = "", artist
            info["artist"] = artist.replace("_", " ").strip()
            info["title"] = title.replace("_", " ").strip()
    stem = os.path.splitext(os.path.basename(path))[0]
    song, _, keys = stem.partition("_")
    info["song_id"] = song
    info["keys"] = keys
    return info


def main(args):
    if not args:
        print(__doc__)
        return
    folder = args[0]
    output = args[1] if len(args) > 1 else "seq_titles.csv"
    files = sorted(
        os.path.join(root, name)
        for root, _, names in os.walk(folder)
        for name in names
        if name.lower().endswith(".seq")
    )
    columns = ["file", "song_id", "keys", "artist", "title", "audio", "bpm", "length", "notes"]
    # utf-8-sig so Excel opens it with the right encoding.
    with open(output, "w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        for path in files:
            try:
                row = read(path)
            except OSError as error:
                row = {"audio": "error: %s" % error}
            row["file"] = os.path.relpath(path, folder)
            writer.writerow(row)
    print("Wrote %d files to %s" % (len(files), output))


if __name__ == "__main__":
    main(sys.argv[1:])
