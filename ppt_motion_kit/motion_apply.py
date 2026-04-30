from __future__ import annotations

import argparse
import re
import zipfile
from pathlib import Path

TRANSITION_XML = {
    "fade": "<p:fade/>",
    "push": "<p:push dir=\"l\"/>",
    "wipe": "<p:wipe dir=\"r\"/>",
    "split": "<p:split/>",
    "cut": "<p:cut/>",
}


def add_transition_to_slide(xml: str, transition: str, speed: str) -> str:
    xml = re.sub(r"<p:transition[\s\S]*?</p:transition>", "", xml)
    xml = re.sub(r"<p:transition[^>]*/>", "", xml)
    node = f'<p:transition spd="{speed}">{TRANSITION_XML[transition]}</p:transition>'
    if "<p:timing" in xml:
        return xml.replace("<p:timing", node + "<p:timing", 1)
    return xml.replace("</p:sld>", node + "</p:sld>")


def apply_transition(input_file: Path, output_file: Path, transition: str, speed: str) -> None:
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(input_file, "r") as zin, zipfile.ZipFile(output_file, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename.startswith("ppt/slides/slide") and item.filename.endswith(".xml"):
                text = data.decode("utf-8")
                text = add_transition_to_slide(text, transition, speed)
                data = text.encode("utf-8")
            zout.writestr(item, data)


def main() -> None:
    parser = argparse.ArgumentParser(description="Add simple slide transitions to a PPTX file.")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--transition", default="fade", choices=sorted(TRANSITION_XML))
    parser.add_argument("--speed", default="med", choices=["slow", "med", "fast"])
    args = parser.parse_args()
    apply_transition(Path(args.input), Path(args.output), args.transition, args.speed)
    report = Path(args.output).with_suffix(".motion_report.txt")
    report.write_text(f"transition={args.transition}\nspeed={args.speed}\noutput={args.output}\n", encoding="utf-8")
    print(f"Motion PPT generated: {args.output}")
    print(f"Report: {report}")


if __name__ == "__main__":
    main()
