import os
import sys
import time
import zipfile
import subprocess

tpz_path = os.path.expandvars(r"%TEMP%\templates.tpz")
target_dir = os.path.expandvars(r"%APPDATA%\Godot\export_templates\4.7.2.stable")
dist_godot = os.path.abspath("dist_godot")
godot_bin = "Godot_v4.7.2-stable_win64_console.exe"

print("Step 1: Waiting for templates.tpz download to finish (target: ~1.28 GB)...")
last_size = -1
stable_count = 0

while True:
    if os.path.exists(tpz_path):
        sz = os.path.getsize(tpz_path)
        mb = sz / (1024 * 1024)
        print(f"Current download size: {mb:.1f} MB")
        # 1200MB 이상이거나 크기가 10초 이상 변하지 않고 500MB 이상인 경우
        if sz > 1200 * 1024 * 1024:
            print("Download completed by size!")
            break
        if sz == last_size and sz > 100 * 1024 * 1024:
            stable_count += 1
            if stable_count >= 5: # 15초 동안 크기 변동 없음
                print("Download completed (file size stabilized)!")
                break
        else:
            stable_count = 0
            last_size = sz
    time.sleep(3)

print("Step 2: Extracting web export templates from tpz...")
os.makedirs(target_dir, exist_ok=True)
with zipfile.ZipFile(tpz_path, "r") as z:
    for name in z.namelist():
        lower = name.lower()
        if "web" in lower or lower.endswith("version.txt"):
            filename = os.path.basename(name)
            if filename:
                out_path = os.path.join(target_dir, filename)
                print(f"Extracting: {filename}")
                with open(out_path, "wb") as f:
                    f.write(z.read(name))

print("Templates extracted to:", target_dir)

print("Step 3: Exporting Godot project to Web (HTML5/WASM)...")
os.makedirs(dist_godot, exist_ok=True)
cmd = [
    godot_bin, "--headless", "--path", "godot_hwashung",
    "--export-release", "Web", os.path.join(dist_godot, "index.html")
]
res = subprocess.run(cmd, capture_output=True, text=True)
print("Godot Export Output:\n", res.stdout)
if res.stderr:
    print("Godot Export Stderr:\n", res.stderr)

if not os.path.exists(os.path.join(dist_godot, "index.html")):
    print("Export failed! Output files not generated.")
    sys.exit(1)

print("Step 4: Launching local Godot Web Server (Port 3001)...")
# Start server in background
srv_cmd = ["python", "serve_godot_web.py"]
subprocess.Popen(srv_cmd, creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == 'nt' else 0)
time.sleep(2)

print("Step 5: Opening browser tab to http://localhost:3001/ ...")
if os.name == 'nt':
    subprocess.run(["cmd", "/c", "start", "http://localhost:3001/"])

print("All steps completed successfully! Godot Web is running.")
