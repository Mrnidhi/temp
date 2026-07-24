/* PHASE 2 - ELIGIBILITY RADAR (raw Compile warehouse). DRAFT - DO NOT RUN AS-IS.
   Staged 07/24. Every table/column name below marked <VERIFY> must first be confirmed
   against the data dictionaries in office Downloads:
   COMPILE_CLAIMS_ALL/OPEN/CLOSED_CLAIMS_Data_Dictionary.md.
   Run only after Phase 1 probes are judged. Process: confirm names, run one query at
   a time, paste results + any errors back to chat.

   Purpose: upgrade the analysis from "where patients are treated" to "who becomes
   AMTAGVI-eligible, when, and where" - the progression proxy is the trigger.

   R1: THERAPY STOP / SWITCH (progression proxy = eligibility trigger).
   For each patient in the 16,246 cohort: last Yervoy/Opdualag claim date, gap since,
   and whether any later systemic therapy claim exists. A patient whose feeder therapy
   stopped 60-180 days ago with no capture at an ATC = the hot referral list.
   Needs: pharmacy/medical claims table <VERIFY: table name>, NDC list (Yervoy
   00003232711 + Opdualag NDCs <VERIFY>), D_PATIENT_ID join to ATC_CLASSIFIED_FINAL.

   R2: PAYER MIX of the feeder cohort by CLASS_FINAL.
   PRIMARY_PAYER_CHANNEL (Commercial / Medicare / Medicaid / VA-DOD / Other,
   confirmed to exist in the claims dictionary) grouped by ATC vs non-ATC.
   Tests whether non-ATC patients skew to payer types with access barriers.
   Needs: claims table <VERIFY> joined on D_PATIENT_ID, most-recent claim per patient.

   R3: TRUE GEOGRAPHIC WHITE SPACE. Patient ZIP3/MSA <VERIFY: patient attributes
   table + column> vs the ATC roster addresses (Tim's workbook has all site
   addresses). Output: feeder patients living >X miles from any ATC, by MSA.
   This is the map exhibit for the brief.

   R4: MEGA-NETWORK ROLLUP. Tag non-ATC parents belonging to national community
   networks (Texas Oncology + US Oncology family, Florida Cancer + OneOncology,
   American Oncology Network, Rocky Mountain Cancer Centers ...) via HCO_COMMUNITY_NE*
   column on ATC_CLASSIFIED_FINAL <VERIFY exact name> plus a name-pattern list.
   Output: feeder volume per network = the BD partnership sizing table.

   R5 (stretch): TRUE TREATMENT DURATION in days (first->last feeder claim per
   patient) by CLASS_FINAL, replacing the claims-count persistence proxy. */

SELECT 'draft - verify names against dictionaries before writing runnable SQL' AS NOTE;
