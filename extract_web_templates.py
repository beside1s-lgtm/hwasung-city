import zipfile
import os

tpz_path = os.path.expandvars(r"%TEMP%\templates.tpz")
target_dir = os.path.expandvars(r"%APPDATA%\Godot\export_templates\4.7.2.stable")
os.makedirs(target_dir, exist_ok=True)

if not os.path.exists(tpz_path):
    print("Error: tpz file not found at", tpz_path)
    exit(1)

print(f"Opening {tpz_path} ({os.path.getsize(tpz_path)} bytes)...")
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

print("All web export templates extracted successfully to:", target_dir)
