#!/usr/bin/env python3
"""Helper to decode base64 files for E59 transfer."""
import base64, sys, os
if len(sys.argv) == 3:
    b64_file = sys.argv[1]
    out_file = sys.argv[2]
    with open(b64_file, 'r') as f:
        data = base64.b64decode(f.read())
    os.makedirs(os.path.dirname(out_file), exist_ok=True)
    with open(out_file, 'wb') as f:
        f.write(data)
    print(f"Wrote {len(data)} bytes to {out_file}")
