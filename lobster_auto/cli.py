from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .core import doctor, init_workspace, load_task_file, plan, run_task


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="lobster",
        description="Lobster Auto: safe local automation runner for OpenClaw workflows.",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("doctor", help="Check runtime and workspace status.")
    sub.add_parser("init", help="Create the Lobster Auto workspace.")

    p_plan = sub.add_parser("plan", help="Preview a task JSON file.")
    p_plan.add_argument("task_file")

    p_run = sub.add_parser("run", help="Run a task JSON file.")
    p_run.add_argument("task_file")
    p_run.add_argument("--dry-run", action="store_true", help="Preview without changing files.")
    p_run.add_argument("--yes", action="store_true", help="Actually execute safe steps.")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if args.cmd == "doctor":
            doctor()
            return 0
        if args.cmd == "init":
            root = init_workspace()
            print(f"Lobster Auto workspace: {root}")
            return 0
        if args.cmd == "plan":
            task = load_task_file(args.task_file)
            print(plan(task))
            return 0
        if args.cmd == "run":
            if not args.dry_run and not args.yes:
                print("Refusing to run without --dry-run or --yes. Use --dry-run first.", file=sys.stderr)
                return 2
            task = load_task_file(args.task_file)
            run_task(task, dry_run=args.dry_run or not args.yes, yes=args.yes)
            return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    parser.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
