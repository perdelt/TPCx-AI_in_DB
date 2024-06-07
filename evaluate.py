"""
    Evaluate measurements of the Python Package DBMS Benchmarker - TPCx-AI experiments
    Copyright (C) 2024 Patrick K. Erdelt

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
"""
from dbmsbenchmarker import *
import pandas as pd
pd.set_option("display.max_rows", None)
pd.set_option('display.max_colwidth', None)
import argparse

#import logging
#logging.basicConfig(level=logging.INFO)

if __name__ == '__main__':
	description = """Merge partial subfolder of a result folder
	"""
	# argparse
	parser = argparse.ArgumentParser(description=description)
	parser.add_argument('-r', '--result-folder', help='folder for storing benchmark result files, default is given by timestamp', default='./')
	parser.add_argument('-c', '--code', help='folder for storing benchmark result files, default is given by timestamp', default='')
	args = parser.parse_args()
	resultfolder = args.result_folder
	code = str(args.code)

	# create evaluation object for result folder
	evaluate = inspector.inspector(resultfolder)

	# last Experiment or given code?
	if code == '':
		# dataframe of experiments
		print("##### Found results")
		print(evaluate.get_experiments_preview().sort_values('time'))
		code = evaluate.list_experiments[0]

	# load it
	print("##### Load results ", code)
	evaluate.load_experiment(code, silent=True)

	# get workload properties
	workload_properties = evaluate.get_experiment_workload_properties()
	print(workload_properties['name'], ":", workload_properties['intro'])
	list_queries = evaluate.get_experiment_list_queries()
	list_nodes = evaluate.get_experiment_list_nodes()
	list_dbms = evaluate.get_experiment_list_dbms()
	list_connections = evaluate.get_experiment_list_connections()
	query_properties = evaluate.get_experiment_query_properties()

	# show some results: mean of execution times per query
	print("##### Execution times in [s]")
	df = evaluate.get_aggregated_query_statistics(type='timer', name='execution', query_aggregate='Mean').sort_index().T/1000.
	df.index = df.index.map(lambda i: query_properties[i[1::]]["title"])
	print(df)

	#print("##### Execution times statistics")
	#df1, df2 = evaluate.get_measures_and_statistics(numQuery="1", type='timer', name='execution')

	# result set of query 43 (evaluation store)
	numQuery="43"
	print("#####", query_properties[numQuery]["title"])
	df = evaluate.get_datastorage_df(numQuery, 0)
	print(df)

	numQuery="44"
	print("#####", query_properties[numQuery]["title"])
	df = evaluate.get_datastorage_df(numQuery, 0)
	print(df)

