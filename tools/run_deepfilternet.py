"""Run the pretrained DeepFilterNet3 model on the exported mixtures.

Only used as a reference, nothing is trained.

Usage (from the repo root, after run_controller_ablation has saved the mixtures):
    python tools/run_deepfilternet.py data/dfn_io/validation
    python tools/run_deepfilternet.py data/dfn_io/unseen_test

Reads <folder>/noisy/*.wav and writes <folder>/enhanced/*.wav (16 kHz) and
<folder>/runtime.csv. The model runs at 48 kHz, so files are resampled
16 -> 48 -> 16 kHz.

Setup (Python 3.10):
    conda create -n dfn python=3.10
    conda activate dfn
    pip install -r tools/requirements-dfn.txt
The model weights download automatically the first time.
"""
import csv
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
import torchaudio.functional as AF
from df.enhance import enhance, init_df


def main(folder: Path) -> None:
    noisy_dir = folder / "noisy"
    out_dir = folder / "enhanced"
    out_dir.mkdir(parents=True, exist_ok=True)
    files = sorted(noisy_dir.glob("*.wav"))
    if not files:
        sys.exit(f"No WAV files found in {noisy_dir}")

    model, df_state, _ = init_df()  # default = DeepFilterNet3
    model_sr = df_state.sr()
    torch.set_num_threads(max(1, torch.get_num_threads()))
    rows = []
    for path in files:
        audio, sr = sf.read(path, dtype="float32")
        if audio.ndim > 1:
            audio = audio.mean(axis=1)
        x = torch.from_numpy(audio).unsqueeze(0)
        started = time.perf_counter()
        x48 = AF.resample(x, sr, model_sr)
        y48 = enhance(model, df_state, x48)
        y = AF.resample(y48, model_sr, sr)[0, : x.shape[1]]
        seconds = time.perf_counter() - started
        y = y.numpy()
        if y.shape[0] < audio.shape[0]:
            y = np.pad(y, (0, audio.shape[0] - y.shape[0]))
        sf.write(out_dir / path.name, y, sr, subtype="FLOAT")
        duration = audio.shape[0] / sr
        rows.append([path.stem, f"{seconds:.4f}", f"{seconds / duration:.4f}"])
        print(f"{path.name}: {seconds:.2f} s (RTF {seconds / duration:.3f})")

    with open(folder / "runtime.csv", "w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["case_id", "runtime_s", "real_time_factor"])
        writer.writerows(rows)
    print(f"Wrote {len(rows)} files to {out_dir}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]))
