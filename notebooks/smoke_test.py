"""Smoke test: extract all code cells from the notebook and check Python syntax."""
import json, ast, sys

path = r"c:\Users\momo-\Downloads\Kimi_Agent_STROLL Voice‑Curated Social App\stroll-rust-flutter\notebooks\pulse_gemma4_finetune.ipynb"

with open(path, encoding="utf-8") as f:
    nb = json.load(f)

errors = []
cell_num = 0
for i, cell in enumerate(nb["cells"]):
    if cell["cell_type"] != "code":
        continue
    cell_num += 1
    source = "".join(cell["source"])
    
    # Strip shell commands (lines starting with !)
    py_lines = []
    for line in source.split("\n"):
        stripped = line.lstrip()
        if stripped.startswith("!"):
            py_lines.append("pass")
        else:
            py_lines.append(line)
    py_source = "\n".join(py_lines)
    
    try:
        ast.parse(py_source)
        print(f"  Cell {cell_num} (idx={i}): OK")
    except SyntaxError as e:
        errors.append((cell_num, i, str(e)))
        print(f"  Cell {cell_num} (idx={i}): FAIL - {e}")

print(f"\nTotal code cells: {cell_num}")
print(f"Syntax errors: {len(errors)}")

if errors:
    for cn, idx, msg in errors:
        print(f"  Cell {cn} (idx={idx}): {msg}")
    sys.exit(1)
else:
    print("All cells pass Python syntax check!")
    ncells = len(nb["cells"])
    print(f"Notebook structure valid ({ncells} cells)")
