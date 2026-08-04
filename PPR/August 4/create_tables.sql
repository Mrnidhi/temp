-- Output tables for the daily P&PR job. The job creates them if they are
-- missing; this file exists so the schema is reviewable and so grants happen.

create schema if not exists ppr;

-- The final table. Tableau reads this and nothing else.
create table if not exists ppr.ppr_events (
    center           varchar(256),
    metric_group     varchar(64),
    metric           varchar(160),
    metric_order     int,
    agg              varchar(16),
    event_date       date,
    value            double precision,
    unit             varchar(256),
    col_label        varchar(32),
    col_order        int,
    cell_color       varchar(32),
    col_group        varchar(64),
    col_group_order  int
);

-- No unique key on purpose. One event appears once per scorecard column it
-- belongs to, so identical looking rows are real. Never deduplicate this table.

-- The reference table, one row per order. Not used by the dashboard; it is
-- what you join to when someone asks which orders produced a number.
create table if not exists ppr.ppr_order_master (
    order_request__til_order_name  varchar(256),
    coi_number                     varchar(256),
    iovance_patient_id             varchar(256),
    atc                            varchar(256),
    center_key                     varchar(256),
    region                         varchar(256),
    territory                      varchar(256),
    atc_segment                    varchar(256),
    atc_tier                       varchar(256),
    enrollment_date                date,
    tumor_pickup_date              date,
    fp_delivery_date               date,
    infusion_date                  date,
    fp_status                      varchar(256),
    oos_status                     varchar(256),
    til_order_cancellation_reason  varchar(256),
    tpf_count                      int,
    has_tumor                      boolean,
    has_slot                       boolean,
    completed_ttp                  boolean,
    scheduled_ttp                  boolean,
    oos_product                    boolean,
    mfg_started                    boolean,
    dropout_post_ttp_health        boolean,
    drop_after_mfg                 boolean,
    amtagvi_infused                boolean,
    ttp_cancel_le7                 boolean,
    days_enroll_to_ttp             double precision,
    days_ttp_to_infusion           double precision,
    days_delivery_to_infusion      double precision
);

-- grant usage on schema ppr to group tableau_readers;
-- grant select on ppr.ppr_events to group tableau_readers;
-- grant select on ppr.ppr_order_master to group tableau_readers;
