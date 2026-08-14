#!/usr/bin/env python3
import os
import shutil
from pathlib import Path


source = Path(f"/tmp/x509up_u{os.getuid()}")
target = Path("x509up_user.pem")

if not source.is_file():
    raise SystemExit(
        f"Proxy not found at {source}; run "
        "voms-proxy-init --rfc --voms cms --valid 192:00 first."
    )

shutil.copy2(source, target)
target.chmod(0o600)
print(f"Copied {source} to {target}")
