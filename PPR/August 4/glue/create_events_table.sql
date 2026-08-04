-- One time setup for the reporting side. The job creates the table if it is
-- missing, this script exists so the DDL is reviewable and so grants happen.

create schema if not exists ppr;

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

-- the table has no unique key on purpose. Rows repeat per scorecard column and
-- identical looking rows are real events. Never deduplicate it.

-- grant select to whatever user or group Tableau connects as:
-- grant usage on schema ppr to group tableau_readers;
-- grant select on ppr.ppr_events to group tableau_readers;
