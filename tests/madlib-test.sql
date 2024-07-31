DROP TABLE IF EXISTS patients, patients_logregr, patients_logregr_summary;
 
CREATE TABLE patients( id INTEGER NOT NULL,
                        second_attack INTEGER,
                        treatment INTEGER,
                        trait_anxiety INTEGER);
                          
INSERT INTO patients VALUES                                                     
(1,     1,      1,      70),
(3,     1,      1,      50),
(5,     1,      0,      40),
(7,     1,      0,      75),
(9,     1,      0,      70),
(11,    0,      1,      65),
(13,    0,      1,      45),
(15,    0,      1,      40),
(17,    0,      0,      55),
(19,    0,      0,      50),
(2,     1,      1,      80),
(4,     1,      0,      60),
(6,     1,      0,      65),
(8,     1,      0,      80),
(10,    1,      0,      60),
(12,    0,      1,      50),
(14,    0,      1,      35),
(16,    0,      1,      50),
(18,    0,      0,      45),
(20,    0,      0,      60);


SELECT madlib.logregr_train(
    'patients',                                 -- source table
    'patients_logregr',                         -- output table
    'second_attack',                            -- labels
    'ARRAY[1, treatment, trait_anxiety]',       -- features
    NULL,                                       -- grouping columns
    20,                                         -- max number of iteration
    'irls'                                      -- optimizer
    );

 SELECT * from patients_logregr;
