-- Foreign key indexes
CREATE INDEX idx_train_order_customer_sk ON train."order"(o_customer_sk);
CREATE INDEX idx_score_order_customer_sk ON score."order"(o_customer_sk);
CREATE INDEX idx_serve_order_customer_sk ON serve."order"(o_customer_sk);
CREATE INDEX idx_train_lineitem_order_id ON train.lineitem(li_order_id);
CREATE INDEX idx_train_lineitem_product_id ON train.lineitem(li_product_id);
CREATE INDEX idx_score_lineitem_order_id ON score.lineitem(li_order_id);
CREATE INDEX idx_score_lineitem_product_id ON score.lineitem(li_product_id);
CREATE INDEX idx_serve_lineitem_order_id ON serve.lineitem(li_order_id);
CREATE INDEX idx_serve_lineitem_product_id ON serve.lineitem(li_product_id);
CREATE INDEX idx_train_order_returns_order_id ON train.order_returns(or_order_id);
CREATE INDEX idx_train_order_returns_product_id ON train.order_returns(or_product_id);
CREATE INDEX idx_score_order_returns_order_id ON score.order_returns(or_order_id);
CREATE INDEX idx_score_order_returns_product_id ON score.order_returns(or_product_id);
CREATE INDEX idx_serve_order_returns_order_id ON serve.order_returns(or_order_id);
CREATE INDEX idx_serve_order_returns_product_id ON serve.order_returns(or_product_id);

-- Non-foreign key indexes
CREATE INDEX idx_failures_serial_model ON train.failures(serial_number, model);
CREATE INDEX idx_failures_failure ON train.failures(failure);

CREATE INDEX idx_failures_serial_model ON score.failures(serial_number, model);
CREATE INDEX idx_failures_failure ON score.failures(failure);

CREATE INDEX idx_failures_serial_model ON serve.failures(serial_number, model);
CREATE INDEX idx_failures_failure ON serve.failures(failure);

CREATE INDEX idx_failures_labels_serial_model ON score.failures_labels(serial_number, model);
CREATE INDEX idx_failures_labels_failure ON score.failures_labels(failure);

CREATE INDEX id_lineitem ON train.lineitem(li_order_id, li_product_id);
CREATE INDEX id_lineitem ON score.lineitem(li_order_id, li_product_id);
CREATE INDEX id_lineitem ON serve.lineitem(li_order_id, li_product_id);







create index idx_train_financial_transactions_senderID on train.financial_transactions(senderID);
create index idx_score_financial_transactions_senderID on score.financial_transactions(senderID);
create index idx_serve_financial_transactions_senderID on serve.financial_transactions(senderID);

