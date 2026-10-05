#!/usr/bin/env python3
"""Usage: extract.py <built index.html> <dir>

Recreates body.html and source.md in <dir> from a page that build.py wrote, so the page can be
edited and rebuilt. build.py escapes every "</script" in the Markdown as "<\\/script" so the
#md-source block cannot close early; this script turns it back into "</script". Prints the two
paths and exits 0, or exits 1 when the page was not built by build.py.
"""
import os
import re
import sys


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        return 2
    page_path, out_dir = sys.argv[1], sys.argv[2]
    with open(page_path, encoding="utf-8") as f:
        page = f.read()
    m = re.search(r'<body>(.*?)\n<script id="md-source" type="text/markdown">\n(.*?)\n</script>', page, re.S)
    if not m:
        print("%s has no <body> followed by a #md-source block; it was not built by build.py" % page_path,
              file=sys.stderr)
        return 1
    os.makedirs(out_dir, exist_ok=True)
    body_path = os.path.join(out_dir, "body.html")
    md_path = os.path.join(out_dir, "source.md")
    with open(body_path, "w", encoding="utf-8") as f:
        f.write("<body>" + m.group(1) + "</body>\n")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(m.group(2).replace("<\\/script", "</script"))
    print("wrote %s" % body_path)
    print("wrote %s" % md_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
