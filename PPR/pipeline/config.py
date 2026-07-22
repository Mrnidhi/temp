"""One-time configuration for the PPR pipeline.

SET THE DATA FOLDER (and optionally the data date) ONCE BELOW. Every script imports
from here, so this is the only place you ever edit to point the pipeline at your files.
"""
import os
import datetime

# ============================================================================
# 1) SET THIS ONCE: the folder that holds ALL your Infinity Excel files.
#   - Default "data" uses the `data` folder inside PPR  (drop your files in PPR/data/).
#   - Or set an absolute path, e.g.:  DATA_DIR = r"C:\Users\you\Desktop\data"
DATA_DIR = "data"

# 2) The "source data as of" date. Splits Completed vs Scheduled TTPs (past vs future).
#   - Leave as None to use today's date when you run.
#   - Or pin it to the Infinity extract date, e.g.:  AS_OF = "2026-07-21"
AS_OF = None
# ============================================================================
AS_OF_DATE = datetime.date.today().isoformat() if AS_OF is None else AS_OF

# --- resolution (no need to edit below) ---
_PPR_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # the PPR/ folder
if not os.path.isabs(DATA_DIR):
    DATA_DIR = os.path.join(_PPR_ROOT, DATA_DIR)
DATA_DIR = os.environ.get("PPR_INPUT_DIR", DATA_DIR)   # env var overrides, if ever set

# shared output folders (also derived from the PPR root)
ANALYSIS_DIR = os.path.join(_PPR_ROOT, "analysis")
TABLEAU_DIR = os.path.join(_PPR_ROOT, "tableau")
