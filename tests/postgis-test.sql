CREATE EXTENSION postgis;

SELECT PostGIS_Full_Version();

CREATE TABLE locations (
    id serial PRIMARY KEY,
    name varchar(50),
    geom geometry(Point, 4326) -- Using SRID 4326 for WGS 84
);

INSERT INTO locations (name, geom)
VALUES 
('Point A', ST_GeomFromText('POINT(30 10)', 4326)),
('Point B', ST_GeomFromText('POINT(40 20)', 4326));


SELECT 
    a.name as point_a,
    b.name as point_b,
    ST_Distance(a.geom, b.geom) as distance
FROM 
    locations a, 
    locations b
WHERE 
    a.name = 'Point A' 
    AND b.name = 'Point B';
