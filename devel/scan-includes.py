#!/usr/bin/env python3
from os import linesep
from sys import argv, exit as sys_exit
import json


def usage():
    print("Usage: scan-includes.py /path/to/compile_commands.json [filter1 [filter2 [... [filter N]]]]"
          "       - str:filterN = \"file\" startswith"
          "Example: "
          "  scan-includes.py ./build/compile_commands.json '/home/kid/virtual/projects/wireshark/epan/dissectors'")
    sys_exit(1)


def main(args):
    compile_commands_path = args[0]
    filters = args[1:]
    with open(compile_commands_path, "r") as f:
        data = json.load(f)

    includes = set()
    functs = set()
    warns = set()
    defines = set()

    for e in data:
        process = len(filters) == 0
        for filter in filters:
            process = process or e["file"].startswith(filter)
        if not process:
            continue

        next_isystem = False
        for arg in e["arguments"]:
            if arg.startswith("-I"):
                includes.add(arg)
            elif arg == "-isystem":
                next_isystem = True
            elif next_isystem:
                includes.add("-I" + arg)
                next_isystem = False
            if arg.startswith("-W"):
                warns.add(arg)
            if arg.startswith("-f"):
                functs.add(arg)
            if arg.startswith("-D"):
                defines.add(arg)

    includes = sorted(list(includes))
    defines = sorted(list(defines))
    functs = sorted(list(functs))
    warns = sorted(list(includes))
    print(*includes, "", sep=linesep)
    print(*defines, "", sep=linesep)
    print(*functs, "", sep=linesep)
    print(*warns, sep=linesep)


if __name__ == "__main__":
    try:
        main(argv[1:])
    except Exception:
        usage()
