CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE "metrics"(
    created timestamp with time zone default now() not null,
    type_id integer                                not null,
    value   double precision                       not null
);


SELECT create_hypertable('metrics', by_range('created'));

CREATE MATERIALIZED VIEW kwh_day_by_day(time, value)
    with (timescaledb.continuous) as
SELECT time_bucket('1 day', created, 'Europe/Berlin') AS "time",
        round((last(value, created) - first(value, created)) * 100.) / 100. AS value
FROM metrics
WHERE type_id = 5
GROUP BY 1;


select * from kwh_day_by_day;