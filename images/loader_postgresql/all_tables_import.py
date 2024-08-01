import csv
import os
import time
from typing import Union
import fnmatch
import psycopg
import tempfile
import logging

# decorator for timing functions
def time_function(func):
    def wrapper(*args, **kwargs):
        logging.info(f"Starting: {func.__name__}...")
        start_time = time.time()
        result = func(*args, **kwargs)
        elapsed_time = time.time() - start_time
        logging.info(f"Finished {func.__name__} in {elapsed_time:.2f} seconds")
        return result
    return wrapper

# data cleaning and preprocessing helper functions
def custom_csv_parser(file_path):
    with tempfile.NamedTemporaryFile(mode='w+', delete=False, newline='', encoding="utf-8") as temp_file:
        with open(file_path, 'r', encoding='utf-8', errors='replace') as infile:
            reader = csv.reader(infile)
            writer = csv.writer(temp_file)
            
            header_row = next(reader)
            writer.writerow(header_row)
            
            if len(header_row) == 13:
                for row in reader:
                    if len(row) == 14:
                        row[10] = row[10] + ", " + row[11]
                        del row[11]
                    writer.writerow(row)
            
            if len(header_row) == 12:
                for row in reader:
                    if len(row) == 13:
                        row[10] = row[10] + ", " + row[11]
                        del row[11]
                    writer.writerow(row)
        
        temp_file.flush()
        temp_file.seek(0)
        
        return temp_file.name

def preprocess_csv(file_path, if_remove_duplicates, primary_key_columns):
    delimiter = detect_delimiter(file_path)
    
    if 'customer.csv' in file_path:
        file_path = custom_csv_parser(file_path)
    
    temp_file_path, header = read_and_process_csv(file_path, delimiter, primary_key_columns if if_remove_duplicates else None)
    
    return header, temp_file_path

def detect_delimiter(file: Union[str, object]) -> str:
    if isinstance(file, str):
        with open(file, 'r', encoding='utf-8') as f:
            return detect_delimiter(f)
    else:
        first_line = file.readline()
        file.seek(0)
        
    common_delimiters = [',', ';', '\t', '|']
    for delimiter in common_delimiters:
        if delimiter in first_line:
            return delimiter
    
    return ','

@time_function
def read_and_process_csv(file_path, delimiter, primary_key_columns=None, remove_quotes=True):
    with tempfile.NamedTemporaryFile(mode='w+', encoding='utf-8', delete=False, newline='') as temp_file:
        writer = csv.writer(temp_file, delimiter=delimiter, quotechar='"', quoting=csv.QUOTE_MINIMAL if remove_quotes else csv.QUOTE_NONE)
        
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as input_file:
            reader = csv.reader(input_file, delimiter=delimiter, quotechar='"', quoting=csv.QUOTE_MINIMAL if remove_quotes else csv.QUOTE_NONE)
            header = next(reader)
            writer.writerow(header)
            
            if primary_key_columns:
                primary_key_indices = [header.index(pk) for pk in primary_key_columns]
                seen = set()
                for row in reader:
                    pk = tuple(row[index] for index in primary_key_indices)
                    if pk not in seen:
                        writer.writerow(row)
                        seen.add(pk)
            else:
                for row in reader:
                    writer.writerow(row)
        
        temp_file.flush()
        temp_file.seek(0)
        
        return temp_file.name, header

@time_function
def create_tables_with_given_sql_instruction(file_path, cursor, conn):
    with open(file_path, 'r', encoding='utf-8') as f:
        sql_file_content = f.read()
        statements = sql_file_content.split(';')
        
        for statement in statements:
            clean_statement = statement.strip()
            if clean_statement:
                cursor.execute(clean_statement)
        
        conn.commit()

@time_function
def create_indexes_with_given_sql_instruction(file_path, cursor, conn):
    with open(file_path, 'r', encoding='utf-8') as f:
        sql_file_content = f.read()
        statements = sql_file_content.split(';')
        
        for statement in statements:
            clean_statement = statement.strip()
            if clean_statement:
                cursor.execute(clean_statement)
        
        conn.commit()

@time_function
def import_csv_to_table(cursor, file_path, headers, table_name, schema='public'):
    with open(file_path, 'r', encoding='utf-8') as file:
        delimiter = detect_delimiter(file)
        
        if table_name is None:
            raise ValueError("Table name cannot be None")
        
        column_names = ', '.join([f'"{str(name).lower()}"' for name in headers])
        
        try:
            copy_command = f'''COPY "{schema}"."{table_name}"({column_names}) FROM STDIN (DELIMITER '{delimiter}', FORMAT CSV, HEADER TRUE)'''
            with cursor.copy(copy_command) as copy:
                while data := file.read():
                    copy.write(data)
        finally:
            pass

def get_correct_file_name(file, path):
    file_lower = file.lower()
    
    for item in os.listdir(path):
        if fnmatch.fnmatch(item.lower(), file_lower):
            return item
    
    return None

if __name__ == '__main__':
    # Configure logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    
    # Path to the data folder
    data_path = '/data/tpcxai/SF'+os.getenv('TPCxAI_SCALE_FACTOR')
    print("Looking for data at", data_path)
    #data_path = 'D:\\data\\tpcxai\\SF10'
    
    # Path to generate_tables.sql file
    generate_tables_sql = './generate_tables.sql'
    create_indexes_sql = './create_indexes.sql'

    # Database connection parameters
    db_name = os.getenv('DATABASE') if os.getenv('DATABASE') else "postgres"
    db_user = os.getenv('USER') if os.getenv('USER') else "postgres"
    db_host = os.getenv('BEXHOMA_HOST') if os.getenv('BEXHOMA_HOST') else "localhost"
    db_port = os.getenv('BEXHOMA_PORT') if os.getenv('BEXHOMA_PORT') else "5432"
    db_password = os.getenv('PASSWORD') if os.getenv('PASSWORD') else "postgres"#os.getenv('DB_PASSWORD')
    
    # list of files to be imported to the database
    files = ['conversation_audio.csv', 'customer_images_meta.csv', 'customer.csv', 'failures.csv', 'failures_labels.csv', 'financial_account.csv', \
             'financial_transactions.csv', 'product.csv', 'order.csv', 'lineitem.csv', 'marketplace.csv', \
             'order_returns.csv', 'productrating.csv', 'review.psv', 'review_labels.psv', 'store_dept.csv', 'conversation_audio_labels.csv', \
             'customer_images_meta_labels.csv', 'customer_labels.csv',  \
             'financial_transactions_labels.csv', 'marketplace_labels.csv', \
             'order_labels.csv', 'productrating_labels.csv', 'store_dept_labels.csv', 'sales.csv']
    
    # dictionary of tables with duplicate primary keys
    duplicates_pk_dic = {
        'financial_account': ['fa_customer_sk'], 
        'financial_transactions': ['transactionID'],
        'financial_transactions_labels': ['transactionID'],
        'customer_image_meta_labels.csv': ['img_filename'],
        'customer_labels.csv': ['c_customer_sk'],
        'customer': ['c_customer_sk'],
        'order': ['o_order_id'],
        'product': ['p_product_id'],
        'customer_image_meta': ['img_filename'],
        'product_reviews': ['id'],
        'productrating': ['userID','productID'],
        'productrating_labels': ['userID','productID'],
    }
    
    # Database connection parameters
    connstring = f"dbname={db_name} user={db_user} password={db_password} host={db_host} port={db_port}"
    
    # Establishing the connection
    conn = psycopg.connect(conninfo=connstring)
    conn.execute("SET client_encoding TO UTF8")
    #print(conn.info.encoding)

    # initiate the cursor
    start_time = time.time()
    with conn:
        with conn.cursor() as cursor:
            try:
                # Create the tables
                create_tables_with_given_sql_instruction(generate_tables_sql, cursor, conn)
                
                # Iterate through the folders (training, serving, scoring)
                for folder in ['training', 'serving', 'scoring']:
                    logging.info(f'--- Processing folder: {folder} ---')
                    if folder == 'training':
                        schema = 'train'
                    elif folder == 'serving':
                        schema = 'serve'
                    else:
                        schema = 'score'
                    
                    # Iterate through the files in the folder
                    for f in files:
                        logging.info(f'--- Schema: \'{schema}\' | File: \'{f}\' is being processed ... ---')
                        table_name = f"{str(f.split('.')[0]).lower()}"
                        
                        file = get_correct_file_name(f, os.path.join(data_path, folder))
                        
                        if file is None:
                            logging.warning(f'{f} not found in the folder {folder}')
                            continue
                        else:
                            # get the full path of the file
                            file_path = os.path.join(data_path, folder, file)
                            
                            if 'customer.csv' in file_path:
                                # Process 'customer.csv' using custom_csv_parser
                                output_file_path = os.path.join(data_path, folder, 'customer.csv')
                                file_path = custom_csv_parser(file_path)

                            
                            # preprocess the file contents, use duplicates_pk_dic to remove duplicates
                            duplicates = duplicates_pk_dic[table_name] if table_name in duplicates_pk_dic else []
                            headers, temp_file_path = preprocess_csv(
                                file_path,
                                if_remove_duplicates=bool(duplicates),
                                primary_key_columns=duplicates,
                            )
                            
                            # import the file to the database
                            import_csv_to_table(cursor, temp_file_path, headers, table_name, schema=schema)
                            os.unlink(temp_file_path)  # Delete the temporary file after importing the data
                
                conn.commit()  # Commit the changes after processing all the files

                # Create indexes
                create_indexes_with_given_sql_instruction(create_indexes_sql, cursor, conn)
            except Exception as e:
                logging.error(f"An error occurred: {str(e)}")
                conn.rollback()  # Rollback the transaction in case of an error
    
    conn.close()
    logging.info(f'--- Entire process: {time.time() - start_time} seconds ---')