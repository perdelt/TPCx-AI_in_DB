create schema if not exists train;
create schema if not exists score;
create schema if not exists serve;
DROP TABLE if exists train.conversation_audio;
DROP TABLE if exists score.conversation_audio;
DROP TABLE if exists score.conversation_audio_labels;
DROP TABLE if exists serve.conversation_audio;
DROP TABLE if exists train.customer_images_meta;
DROP TABLE if exists score.customer_images_meta;
DROP TABLE if exists score.customer_images_meta_labels;
DROP TABLE if exists serve.customer_images_meta;
DROP TABLE if exists train.customer cascade;
DROP TABLE if exists score.customer cascade;
DROP TABLE if exists score.customer_labels cascade;
DROP TABLE if exists serve.customer cascade;
DROP TABLE if exists train.failures;
DROP TABLE if exists score.failures;
DROP TABLE if exists score.failures_labels;
DROP TABLE if exists serve.failures;
DROP TABLE if exists train.financial_account;
DROP TABLE if exists serve.financial_account;
DROP TABLE if exists score.financial_account;
DROP TABLE if exists train.financial_transactions cascade ;
DROP TABLE if exists score.financial_transactions cascade ;
DROP TABLE if exists score.financial_transactions_labels cascade ;
DROP TABLE if exists serve.financial_transactions cascade ;
DROP TABLE if exists train.product cascade;
DROP TABLE if exists score.product cascade;
DROP TABLE if exists serve.product cascade;
DROP TABLE if exists train."order" cascade;
DROP TABLE if exists score."order" cascade;
DROP TABLE if exists score.order_labels cascade;
DROP TABLE if exists serve."order" cascade;
DROP TABLE if exists train.lineitem CASCADE;
DROP TABLE if exists score.lineitem CASCADE;
DROP TABLE if exists serve.lineitem CASCADE;
DROP TABLE if exists train.marketplace;
DROP TABLE if exists score.marketplace;
DROP TABLE if exists score.marketplace_labels;
DROP TABLE if exists serve.marketplace;
DROP TABLE if exists train.order_returns;
DROP TABLE if exists score.order_returns;
DROP TABLE if exists serve.order_returns;
DROP TABLE if exists train.productrating CASCADE;
DROP TABLE if exists score.productrating CASCADE;
DROP TABLE if exists score.productrating_labels;
DROP TABLE if exists serve.productrating;
DROP TABLE if exists train.review;
DROP TABLE if exists score.review;
DROP TABLE if exists score.review_labels;
DROP TABLE if exists serve.review;
DROP TABLE if exists train.store_dept cascade;
DROP TABLE if exists score.store_dept cascade;
DROP TABLE if exists score.store_dept_labels cascade;
DROP TABLE if exists serve.store_dept;
DROP TABLE if exists score.sales;
DROP TABLE if exists serve.sales;


CREATE TABLE train.conversation_audio (
	wav_filename varchar NOT NULL,
	transcript varchar NULL,
	PRIMARY KEY (wav_filename)
);

CREATE TABLE score.conversation_audio (
	wav_filename varchar NOT NULL,
	PRIMARY KEY (wav_filename)
);

CREATE TABLE score.conversation_audio_labels (
	wav_filename varchar NOT NULL,
	transcript varchar NULL,
	PRIMARY KEY (wav_filename)
);

CREATE TABLE serve.conversation_audio (
	wav_filename varchar NOT NULL,
	PRIMARY KEY (wav_filename)
);

CREATE TABLE train.customer_images_meta (
	identity_serving varchar NULL,
	sample int4 NULL,
	img_filename varchar NOT NULL,
	PRIMARY KEY (img_filename)
);

CREATE TABLE score.customer_images_meta (
	identity_serving varchar NULL,
	sample int4 NULL,
	img_filename varchar NOT NULL,
	PRIMARY KEY (img_filename)
);

CREATE TABLE score.customer_images_meta_labels (
	identity varchar(255) Null,
	identity_serving varchar NULL,
	sample int4 NULL,
	img_filename varchar NOT NULL,
	PRIMARY KEY (img_filename)
);

CREATE TABLE serve.customer_images_meta (
	identity_serving varchar NULL,
	sample int4 NULL,
	img_filename varchar NOT NULL,
	PRIMARY KEY (img_filename)
);

CREATE TABLE train.customer ( 
	c_customer_sk int4 NOT NULL,
	c_customer_id varchar NULL,
	c_current_addr_sk int4 NULL,
	c_first_name varchar NULL,
	c_last_name varchar NULL,
	c_preferred_cust_flag varchar(1) NULL,
	c_birth_day int4 NULL,
	c_birth_month int4 NULL,
	c_birth_year int4 NULL,
	c_birth_country varchar NULL,
	c_login varchar NULL,
	c_email_address varchar NULL,
	c_cluster_id int4 NULL,
	PRIMARY KEY (c_customer_sk)
);

CREATE TABLE score.customer ( 
	c_customer_sk int4 NOT NULL,
	c_customer_id varchar NULL,
	c_current_addr_sk int4 NULL,
	c_first_name varchar NULL,
	c_last_name varchar NULL,
	c_preferred_cust_flag varchar(1) NULL,
	c_birth_day int4 NULL,
	c_birth_month int4 NULL,
	c_birth_year int4 NULL,
	c_birth_country varchar NULL,
	c_login varchar NULL,
	c_email_address varchar NULL,
	PRIMARY KEY (c_customer_sk)
);

CREATE TABLE score.customer_labels(
    c_customer_sk int4 NOT NULL,
    c_cluster_id int4 null,
    primary key (c_customer_sk)
);

CREATE TABLE serve.customer ( 
	c_customer_sk int4 NOT NULL,
	c_customer_id varchar NULL,
	c_current_addr_sk int4 NULL,
	c_first_name varchar NULL,
	c_last_name varchar NULL,
	c_preferred_cust_flag varchar(1) NULL,
	c_birth_day int4 NULL,
	c_birth_month int4 NULL,
	c_birth_year int4 NULL,
	c_birth_country varchar NULL,
	c_login varchar NULL,
	c_email_address varchar NULL,
	PRIMARY KEY (c_customer_sk)
);

 -- id is needed because of madlib features
CREATE TABLE train.failures (
	id serial4 primary key,
	date date NULL,
	serial_number varchar NULL,
	model varchar(255) NULL,
	failure int4 NULL,
	smart_5_raw float8 NULL,
	smart_10_raw float8 NULL,
	smart_184_raw float8 NULL,
	smart_187_raw float8 NULL,
	smart_188_raw float8 NULL,
	smart_197_raw float8 NULL,
	smart_198_raw float8 NULL
);


CREATE TABLE score.failures (
	id serial4 primary key,
	date date NULL,
	serial_number varchar NULL,
	model varchar(255) NULL,
	failure int4 NULL,
	smart_5_raw float8 NULL,
	smart_10_raw float8 NULL,
	smart_184_raw float8 NULL,
	smart_187_raw float8 NULL,
	smart_188_raw float8 NULL,
	smart_197_raw float8 NULL,
	smart_198_raw float8 NULL
);


CREATE TABLE score.failures_labels (
	id serial4 primary key,
	date date NULL,
	serial_number varchar NULL,
	model varchar(255) NULL,
	failure int4 NULL
);


CREATE TABLE serve.failures (
	id serial4 primary key,
	date date NULL,
	serial_number varchar NULL,
	model varchar(255) NULL,
	failure int4 NULL,
	smart_5_raw float8 NULL,
	smart_10_raw float8 NULL,
	smart_184_raw float8 NULL,
	smart_187_raw float8 NULL,
	smart_188_raw float8 NULL,
	smart_197_raw float8 NULL,
	smart_198_raw float8 NULL
);


CREATE TABLE train.financial_account (
	fa_customer_sk bigint NOT NULL,
	transaction_limit decimal(8,2) NULL,
	PRIMARY KEY (fa_customer_sk)
);

CREATE TABLE serve.financial_account (
	fa_customer_sk bigint NOT NULL,
	transaction_limit decimal(8,2) NULL,
	PRIMARY KEY (fa_customer_sk)
);

CREATE TABLE score.financial_account (
	fa_customer_sk bigint NOT NULL,
	transaction_limit decimal(8,2) NULL,
	PRIMARY KEY (fa_customer_sk)
);

CREATE TABLE train.financial_transactions(
	transactionID bigint not NULL,
    amount double precision NULL,
	IBAN varchar NULL,
	senderID bigint NULL,
	receiverID text NULL,
	isFraud boolean NULL,
	"time" timestamp NULL,
	PRIMARY KEY (transactionID)
);

CREATE TABLE score.financial_transactions(
	transactionID bigint not NULL,
    amount double precision NULL,
	IBAN varchar NULL,
	senderID bigint NULL,
	receiverID text NULL,
	"time" timestamp NULL,
	PRIMARY KEY (transactionID)
);

CREATE TABLE score.financial_transactions_labels(
	transactionID bigint not NULL,
	isFraud boolean NULL,
	PRIMARY KEY (transactionID)
);

CREATE TABLE serve.financial_transactions( 
	transactionID bigint not NULL,
    amount double precision NULL,
	IBAN varchar NULL,
	senderID bigint NULL,
	receiverID text NULL,
	"time" timestamp NULL,
	PRIMARY KEY (transactionID)
);

CREATE TABLE train.product( 
	p_product_id int4 NOT NULL,
	"name" varchar NULL,
	department varchar NULL,
	PRIMARY KEY (p_product_id)
);

CREATE TABLE score.product( 
	p_product_id int4 NOT NULL,
	"name" varchar NULL,
	department varchar NULL,
	PRIMARY KEY (p_product_id)
);

CREATE TABLE serve.product( 
	p_product_id int4 NOT NULL,
	"name" varchar NULL,
	department varchar NULL,
	PRIMARY KEY (p_product_id)
);

CREATE TABLE train."order" ( 
	o_order_id int4 NOT NULL,
	o_customer_sk int4 NULL,
    weekday varchar null,
    date DATE NULL,
    store INT NULL,
    trip_type INT NULL,
    PRIMARY KEY (o_order_id),
    foreign key (o_customer_sk) references train.customer(c_customer_sk)
);

CREATE TABLE score."order" ( 
	o_order_id int4 NOT NULL,
	o_customer_sk int4 NULL,
    weekday varchar null,
    date DATE NULL,
    store INT NULL,
    PRIMARY KEY (o_order_id),
    foreign key (o_customer_sk) references score.customer(c_customer_sk)
);

CREATE TABLE score.order_labels ( 
	o_order_id int4 NOT NULL,
    trip_type INT NULL,
    PRIMARY KEY (o_order_id)
);

CREATE TABLE serve."order" ( 
	o_order_id int4 NOT NULL,
	o_customer_sk int4 NULL,
    weekday varchar null,
    date DATE NULL,
    store INT NULL,
    PRIMARY KEY (o_order_id),
    foreign key (o_customer_sk) references serve.customer(c_customer_sk)
);

CREATE TABLE train.lineitem(
    li_order_id INT NOT NULL,
    li_product_id INT NOT NULL,
    quantity INT,
    price NUMERIC(8, 2), -- 8 digits before the decimal and 2 digits after

    foreign key (li_product_id) references train.product(p_product_id),
    FOREIGN KEY (li_order_id) REFERENCES train."order"(o_order_id)
);


CREATE TABLE score.lineitem(
    li_order_id INT NOT NULL,
    li_product_id INT NOT NULL,
    quantity INT,
    price NUMERIC(8, 2), -- 8 digits before the decimal and 2 digits after

    foreign key (li_product_id) references score.product(p_product_id),
    FOREIGN KEY (li_order_id) REFERENCES score."order"(o_order_id)
);

CREATE TABLE serve.lineitem(
    li_order_id INT NOT NULL,
    li_product_id INT NOT NULL,
    quantity INT,
    price NUMERIC(8, 2), -- 8 digits before the decimal and 2 digits after

    foreign key (li_product_id) references serve.product(p_product_id),
    FOREIGN KEY (li_order_id) REFERENCES serve."order"(o_order_id)
);

CREATE TABLE train.marketplace ( 
	id int4 NOT NULL,
	price decimal(8,2) NULL,
	description varchar NULL,
	PRIMARY KEY (id)
);

CREATE TABLE score.marketplace ( 
	id int4 NOT NULL,
	description varchar NULL,
	PRIMARY KEY (id)
);

CREATE TABLE score.marketplace_labels ( 
	id int4 NOT NULL,
	price decimal(8,2) NULL,
	PRIMARY KEY (id)
);

CREATE TABLE serve.marketplace ( 
	id int4 NOT NULL,
	description varchar NULL,
	PRIMARY KEY (id)
);

CREATE TABLE train.order_returns (
	or_order_id int4 NULL,
	or_product_id int4 NULL,
	or_return_quantity int4 NULL,
    foreign key (or_order_id) references train."order"(o_order_id),
    foreign key (or_product_id) references train.product(p_product_id)
);

CREATE TABLE score.order_returns (
	or_order_id int4 NULL,
	or_product_id int4 NULL,
	or_return_quantity int4 NULL,
    foreign key (or_order_id) references score."order"(o_order_id),
    foreign key (or_product_id) references score.product(p_product_id)
);

CREATE TABLE serve.order_returns (
	or_order_id int4 NULL,
	or_product_id int4 NULL,
	or_return_quantity int4 NULL,
    foreign key (or_order_id) references serve."order"(o_order_id),
    foreign key (or_product_id) references serve.product(p_product_id)
);

CREATE TABLE train.productrating (
	userID int4 NULL,
	productID int4 NULL,
	rating int4 NULL,
	primary key (userID, productID)
);

CREATE TABLE score.productrating (
	userID int4 NULL,
	productID int4 NULL,
	primary key (userID, productID)
);

CREATE TABLE score.productrating_labels (
	userID int4 NULL,
	productID int4 NULL,
	rating int4 NULL,
	primary key (userID, productID)
);

CREATE TABLE serve.productrating (
	userID int4 NULL,
	productID int4 NULL,
	primary key (userID, productID)
);

CREATE TABLE train.review (
	ID int4 NOT NULL,
	spam int4 NULL,
	"text" varchar NULL,
	PRIMARY KEY (ID)
);

CREATE TABLE score.review (
	ID int4 NOT NULL,
	"text" varchar NULL,
	PRIMARY KEY (ID)
);

CREATE TABLE score.review_labels (
	ID int4 NOT NULL,
	spam int4 NULL,
	PRIMARY KEY (ID)
);

CREATE TABLE serve.review (
	ID int4 NOT NULL,
	"text" varchar NULL,
	PRIMARY KEY (ID)
);

CREATE TABLE train.store_dept (
	store int4 NULL,
	department varchar NULL,
	PRIMARY KEY (store, department)
);

CREATE TABLE score.store_dept (
	store int4 NULL,
	department varchar NULL,
	periods int4 NULL,
	PRIMARY KEY (store, department)
);

CREATE TABLE score.store_dept_labels (
	store int4 NULL,
	department varchar NULL,
	date date NULL,
	weekly_sales float8 NULL,
	PRIMARY KEY (store, department, date)
);

CREATE TABLE serve.store_dept (
	store int4 NULL,
	department varchar NULL,
	periods int4 NULL,
	PRIMARY KEY (store, department)
);

CREATE TABLE score.sales (
	store int4 NULL,
	spread float NULL,
	PRIMARY KEY (store)
);

CREATE TABLE serve.sales (
	store int4 NULL,
	spread float NULL,
	PRIMARY KEY (store)
);


