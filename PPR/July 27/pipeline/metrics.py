"""
The 13 P&PR metrics. Single definition, imported by every stage.

Wording follows the P&PR metrics template verbatim. These strings are shown to treatment
centres, so they are not reworded here.

Declared once and imported everywhere. Declaring them per stage let the wording drift,
which in a reporting tool renders as two different rows for the same metric.
"""

M1 = "Enrollments in IovanceCares"
M2 = "Patients Enrolled in IovanceCares"
M3 = "TTPs Cancelled or Rescheduled within 7 Days Prior to Slot Reservation"
M4 = "Completed TTPs"
M5 = "Scheduled TTPs"
M6 = "2nd Resections (Scheduled or Completed)"
M7 = "Patient Related Drop-outs following TTP due to patient health"
M8 = "OOS Products"
M9 = "Patient Progression Rate"
M10 = "AMTAGVI Infusions Performed"
M11 = "Median Time From Enrollment Date to TTP (Days)"
M12 = "Median Time From TTP to AMTAGVI Infusion (Days)"
M13 = "Median Time From Final Product Delivery Date to AMTAGVI Infusion (Days)"

ENROLL = "Patient Identification & Enrollment"
TTP = "Tumor Tissue Procurement"
REGIMEN = "AMTAGVI Regimen"
TIMELINES = "AMTAGVI Treatment Timelines"

# (order, group, name, value_type)
METRICS = [
    (1,  ENROLL,    M1,  "count"),
    (2,  ENROLL,    M2,  "count"),
    (3,  ENROLL,    M3,  "count"),
    (4,  TTP,       M4,  "count"),
    (5,  TTP,       M5,  "count"),
    (6,  TTP,       M6,  "count"),
    (7,  REGIMEN,   M7,  "count"),
    (8,  REGIMEN,   M8,  "count"),
    (9,  REGIMEN,   M9,  "rate"),
    (10, REGIMEN,   M10, "count"),
    (11, TIMELINES, M11, "days"),
    (12, TIMELINES, M12, "days"),
    (13, TIMELINES, M13, "days"),
]

NAME = {order: name for order, _, name, _ in METRICS}
GROUP = {order: group for order, group, _, _ in METRICS}

# A metric belongs to the period its own event happened in, not the period the patient
# enrolled in, matching the template footnote "Timing metrics based upon the TTP or
# Infusion Date". So the 2025 column of Infusions Performed means infusions that
# happened in 2025.
EVENT_DATE = {
    M1:  "enrollment_date",   M2:  "enrollment_date",   M3:  "tumor_pickup_date",
    M4:  "tumor_pickup_date", M5:  "tumor_pickup_date", M6:  "tumor_pickup_date",
    M7:  "tumor_pickup_date", M8:  "fp_delivery_date",  M9:  "tumor_pickup_date",
    M10: "infusion_date",     M11: "tumor_pickup_date", M12: "infusion_date",
    M13: "infusion_date",
}

# Counts over distinct patients, so they do not sum across periods: a patient with orders
# in two years is one patient launch-to-date but appears in both year columns.
NON_ADDITIVE = {M2, M6, M7}

# Lower is better, so an increase is a worse result. Used wherever a change is coloured.
LOWER_IS_BETTER = {M3, M7, M8, M9, M13}

# Direction for the peer-median shading.
# Everything in neither set is neutral and never coloured: scheduled TTPs and 2nd
# resections are bookings/rarities not performance, and the first two timing medians
# have no agreed good direction. Thresholds live in build_datewindow.heat_band().
HIGHER_IS_BETTER = {M1, M2, M4, M10}
