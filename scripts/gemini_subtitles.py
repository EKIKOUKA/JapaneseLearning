#!/usr/bin/env python3
"""Gemini 2.5 Flash-Lite で音声を字幕化する（Python 標準ライブラリ + ffmpeg）。"""
import argparse
import base64
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def generate(audio, duration, model, key):
    # 各チャンクの先頭を 0 秒として依頼し、保存時に元動画の時刻へ戻す。
    prompt = (
        f"この音声（長さ {duration:.3f} 秒）を日本語のまま逐語的に文字起こししてください。"
        "要約・翻訳・聞こえない発言の補完は禁止です。短い発話ごとに区切り、"
        "各発話の実際の開始・終了時刻を秒数（小数可）で付けてください。"
        "時刻はこの音声の先頭を0秒とし、無音や音楽だけの部分には字幕を付けないでください。"
        "聞き取れない部分は［聞き取り不能］としてください。"
    )
    schema = {"type": "OBJECT", "properties": {"segments": {
        "type": "ARRAY", "items": {"type": "OBJECT", "properties": {
            "start": {"type": "NUMBER"}, "end": {"type": "NUMBER"},
            "text": {"type": "STRING"}}, "required": ["start", "end", "text"]}
    }}, "required": ["segments"]}
    payload = {"contents": [{"role": "user", "parts": [
        {"text": prompt}, {"inlineData": {"mimeType": "audio/mp3",
         "data": base64.b64encode(audio).decode("ascii")}}
    ]}], "generationConfig": {"temperature": 0, "maxOutputTokens": 16384,
        "thinkingConfig": {"thinkingBudget": 0},
        "responseMimeType": "application/json", "responseSchema": schema}}
    request = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                result = json.load(response)
            break
        except urllib.error.HTTPError as error:
            if error.code in (429, 500, 502, 503, 504) and attempt < 2:
                time.sleep(2 ** (attempt + 1))
                continue
            detail = error.read(16384).decode("utf-8", errors="replace").replace(key, "[REDACTED]")
            raise RuntimeError(f"Gemini HTTP {error.code}: {detail}") from None
    candidates = result.get("candidates", [])
    if any(c.get("finishReason") == "RECITATION" for c in candidates):
        raise RuntimeError("Gemini が RECITATION（既存コンテンツの再現に関する制限）で生成を停止しました。字幕は未生成です。")
    if not candidates or candidates[0].get("finishReason") != "STOP":
        raise RuntimeError(f"生成が完了しませんでした: {result.get('promptFeedback') or [c.get('finishReason') for c in candidates]}")
    text = "".join(p.get("text", "") for p in candidates[0]["content"]["parts"] if not p.get("thought"))
    segments = json.loads(text)["segments"]
    previous = -1.0
    for segment in segments:
        start, end = float(segment["start"]), float(segment["end"])
        if not (math.isfinite(start) and math.isfinite(end) and 0 <= start < end <= duration + 0.5 and start >= previous):
            raise RuntimeError(f"不正な字幕時刻: {start} --> {end}（音声長 {duration} 秒）")
        if not isinstance(segment["text"], str) or not segment["text"].strip():
            raise RuntimeError("空の字幕が返されました")
        segment.update(start=start, end=min(end, duration))
        previous = start
    return segments, result.get("usageMetadata", {})


def timestamp(seconds):
    value = round(seconds * 1000)
    return f"{value // 3600000:02}:{value // 60000 % 60:02}:{value // 1000 % 60:02},{value % 1000:03}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--model", default="gemini-2.5-flash-lite")
    parser.add_argument("--chunk-seconds", type=int, default=60)
    parser.add_argument("--limit-seconds", type=float, help="先頭の指定秒数だけテストする")
    parser.add_argument("--output-dir", type=Path, help="既定: 入力ファイルと同じフォルダー")
    args = parser.parse_args()
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        parser.error("環境変数 GEMINI_API_KEY を設定してください")
    if args.chunk_seconds < 1 or (args.limit_seconds is not None and args.limit_seconds <= 0):
        parser.error("秒数は正数で指定してください")
    info = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(args.input)]))
    duration = float(info["format"]["duration"])
    if args.limit_seconds:
        duration = min(duration, args.limit_seconds)
    directory = args.output_dir or args.input.parent
    directory.mkdir(parents=True, exist_ok=True)
    stem = args.input.stem + f".{args.model}" + (f".first-{duration:g}s" if args.limit_seconds else "")
    json_path, srt_path = directory / (stem + ".json"), directory / (stem + ".srt")
    if json_path.exists() or srt_path.exists():
        parser.error("出力ファイルが既に存在します。別の --output-dir を指定してください")
    document = {"source": str(args.input), "model": args.model, "duration": duration,
                "complete": False, "chunks": [], "segments": []}

    def save():
        # 途中で失敗しても、完了済みチャンクの字幕を残す。
        temporary = json_path.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(document, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(json_path)
        srt_path.write_text("\n".join(
            f"{i}\n{timestamp(s['start'])} --> {timestamp(s['end'])}\n{s['text']}\n"
            for i, s in enumerate(document["segments"], 1)), encoding="utf-8")

    with tempfile.TemporaryDirectory(prefix="gemini-subtitles-") as tmp:
        for index in range(math.ceil(duration / args.chunk_seconds)):
            offset = index * args.chunk_seconds
            length = min(args.chunk_seconds, duration - offset)
            print(f"[{index + 1}/{math.ceil(duration / args.chunk_seconds)}] {offset:.1f}–{offset + length:.1f}s", flush=True)
            audio = Path(tmp) / "chunk.mp3"
            subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-ss", str(offset),
                "-i", str(args.input), "-t", str(length), "-vn", "-ac", "1", "-ar", "16000",
                "-b:a", "48k", str(audio)], check=True)
            started = time.monotonic()
            segments, usage = generate(audio.read_bytes(), length, args.model, key)
            for segment in segments:
                segment["start"] = round(segment["start"] + offset, 3)
                segment["end"] = round(segment["end"] + offset, 3)
            document["segments"].extend(segments)
            document["chunks"].append({"offset": offset, "duration": length,
                "elapsed": round(time.monotonic() - started, 2), "usage": usage})
            save()
            print(f"  {len(segments)} 字幕を保存", flush=True)
    document["complete"] = True
    save()
    print(f"JSON: {json_path}\nSRT: {srt_path}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, KeyError) as error:
        raise SystemExit(str(error))
