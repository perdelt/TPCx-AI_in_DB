CREATE EXTENSION IF NOT EXISTS citus;

--
-- Make an ordinary table, which is row-based storage, and a
-- columnar table.
--
CREATE TABLE simple_row(i INT8);
CREATE TABLE simple_columnar(i INT8) USING columnar;

--
-- Columnar tables act like row tables
--
INSERT INTO simple_row SELECT generate_series(1,100000);
INSERT INTO simple_columnar SELECT generate_series(1,100000);
SELECT AVG(i) FROM simple_row;
SELECT AVG(i) FROM simple_columnar;

SELECT *
FROM information_schema.tables
WHERE table_name = 'simple_columnar';
