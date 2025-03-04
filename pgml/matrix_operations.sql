drop table if exists "mat_A";
CREATE TABLE "mat_A" (
        row_id integer,
        row_vec integer[]
);
INSERT INTO "mat_A" (row_id, row_vec) VALUES (1, '{9,6,5,8,5,6,6,3,10,8}');
INSERT INTO "mat_A" (row_id, row_vec) VALUES (2, '{8,2,2,6,6,10,2,1,9,9}');
INSERT INTO "mat_A" (row_id, row_vec) VALUES (3, '{3,9,9,9,8,6,3,9,5,6}');
INSERT INTO "mat_A" (row_id, row_vec) VALUES (4, '{6,4,2,2,2,7,8,8,0,7}');
INSERT INTO "mat_A" (row_id, row_vec) VALUES (5, '{6,8,9,9,4,6,9,5,7,7}');
INSERT INTO "mat_A" (row_id, row_vec) VALUES (6, '{4,10,7,3,9,5,9,2,3,4}');
INSERT INTO "mat_A" (row_id, row_vec) VALUES (7, '{8,10,7,10,1,9,7,9,8,7}');
INSERT INTO "mat_A" (row_id, row_vec) VALUES (8, '{7,4,5,6,2,8,1,1,4,8}');
INSERT INTO "mat_A" (row_id, row_vec) VALUES (9, '{8,8,8,5,2,6,9,1,8,3}');
INSERT INTO "mat_A" (row_id, row_vec) VALUES (10, '{4,6,3,2,6,4,1,2,3,8}');

CREATE TABLE "mat_B" (
    row_id integer,
    vector integer[]
);
INSERT INTO "mat_B" (row_id, vector) VALUES (1, '{9,10,2,4,6,5,3,7,5,6}');
INSERT INTO "mat_B" (row_id, vector) VALUES (2, '{5,3,5,2,8,6,9,7,7,6}');
INSERT INTO "mat_B" (row_id, vector) VALUES (3, '{0,1,2,3,2,7,7,3,10,1}');
INSERT INTO "mat_B" (row_id, vector) VALUES (4, '{2,9,0,4,3,6,8,6,3,4}');
INSERT INTO "mat_B" (row_id, vector) VALUES (5, '{3,8,7,7,0,5,3,9,2,10}');
INSERT INTO "mat_B" (row_id, vector) VALUES (6, '{5,3,1,7,6,3,5,3,6,4}');
INSERT INTO "mat_B" (row_id, vector) VALUES (7, '{4,8,4,4,2,7,10,0,3,3}');
INSERT INTO "mat_B" (row_id, vector) VALUES (8, '{4,6,0,1,3,1,6,6,9,8}');
INSERT INTO "mat_B" (row_id, vector) VALUES (9, '{6,5,1,7,2,7,10,6,0,6}');
INSERT INTO "mat_B" (row_id, vector) VALUES (10, '{1,4,4,4,8,5,2,8,5,5}');

drop table if exists mat_r;
SELECT madlib.matrix_trans('"mat_B"', 'row=row_id, val=vector',
                           'mat_r');
select * from "mat_B" order by row_id;
SELECT * FROM mat_r ORDER BY row_id;
SELECT madlib.matrix_ndims('"mat_A"', 'row=row_id, val=row_vec');

SELECT array_dims(matrix_u) AS u_dims, array_dims(matrix_v) AS v_dims
FROM
WHERE id = 1;