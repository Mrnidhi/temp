# data/

Drop **all your Infinity Excel files** in this folder, then run the pipeline.

The pipeline uses these 5 (filenames may have date suffixes; matching is flexible):
- `bai_list_of_orders`
- `bai_tumor_documentation`
- `bai_infusion`
- `bai_slot_data`
- `veeva_komodo_atc_mapping`

Extra files here (e.g. `bai_ttp_data`, `veeva_call_activity`) are ignored.

This folder's path is set once in `pipeline/config.py` (`DATA_DIR`). If you keep your
files here, you do not need to change anything. To use a different folder, edit that one line.

NOTE: the actual data files are git-ignored on purpose. Real Infinity data must never be
committed or pushed. Only this README is tracked.
