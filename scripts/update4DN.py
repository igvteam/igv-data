# Search the 4DN webservice for data files IGV supports and create tables for each assembly and file type.
# This script creates plain text files in the "output" foloder.  To deploy the tiles should be moved to ../data/4dn

import os
import requests

output_folder = "output"

if not os.path.isdir(output_folder):
    os.mkdir(output_folder)

# Force return from the server in JSON format
HEADERS = {'accept': 'application/json'}

URL = "https://data.4dnucleome.org/search/?" \
      "type=ExperimentSetReplicate&" \
      "experiments_in_set.experiment_type.display_title=in+situ+Hi-C&" \
      "experiments_in_set.experiment_type.display_title=Dilution+Hi-C&" \
      "experiments_in_set.experiment_type.display_title=sn-Hi-C&" \
      "experiments_in_set.experiment_type.display_title=sci-Hi-C&" \
      "experiments_in_set.experiment_type.display_title=single+cell+Hi-C&" \
      "experiments_in_set.experiment_type.display_title=in+situ+ChIA-PET&" \
      "experiments_in_set.experiment_type.display_title=ChIA-PET&" \
      "field=award.project&" \
      "field=processed_files&" \
      "field=dataset_label&" \
      "field=lab.display_title&" \
      "field=experiments_in_set.biosample.biosource.organism.name&" \
      "field=publications_of_set.display_title&" \
      "format=json&" \
      "limit=all"

# GET the object
response = requests.get(URL, headers=HEADERS)

# Extract the JSON response as a python dict
response_json_dict = response.json()
#%%
# Graph object
graph = response_json_dict['@graph']


hic_files = []

def listToString(l):
    result = ''
    for i in range(len(l)):
        if i > 0:
            result += " "
        result += str(l[i])
    return result

hic_results = []
track_results = {}
for record in graph:

    # Extract expermient metada

    id = record["@id"]  #/experiment-set-replicates/4DNES1JP4KZ1/
    study = record['study'] if 'study' in record else ''
    study_group = record['study_group'] if 'study_group' in record else ''
    experiment = record['accession'] if 'accession' in record else id[28:][:-1]
    dataset = record['dataset_label'] if 'dataset' in record else ''
    description = record['description'] if 'description' in record else ''
    lab = record['lab']['display_title']
    project = record['award']['project']

    publications = ""
    if 'publications_of_set' in record:
        for p in record['publications_of_set']:
            if len(publications) > 0:
                publications = publications + ", "
            publications = publications + p['display_title']

    # Loop through process files
    if 'processed_files' in record:

        for file in record['processed_files']:

            if 'open_data_url' in file and 'genome_assembly' in file:

                genome_assembly = file['genome_assembly']
                accession = file['accession']
                file_type = file['file_type']

                if 'track_and_facet_info' in file:
                    track_and_facet_info = file['track_and_facet_info']
                    dataset = track_and_facet_info['dataset'] # Overide
                    assay_info = track_and_facet_info['assay_info']
                    biosource = track_and_facet_info['biosource_name']
                    condition = track_and_facet_info['condition']
                    replicate_info = track_and_facet_info['replicate_info']
                    experiment_type = track_and_facet_info['experiment_type']
                    track_title = track_and_facet_info['track_title'] if 'track_title' in track_and_facet_info else ''

                    if file_type == 'insulation score-diamond':
                        color = 'rgb(3,127,252)'
                        alt_color = 'rgb(11,177,250)'
                    elif file_type == 'compartments':
                        color = 'rgb(249,88,148)'
                        alt_color = 'rgb(213,144,182)'
                    else:
                        color = 'rgb(0, 150, 0)'
                        alt_color = 'rgb(0, 150, 0)'

                url = file['open_data_url']

                if url.endswith('.hic'):

                    hic_results.append([url, project, genome_assembly, biosource, assay_info, replicate_info, dataset, description, lab, publications, accession, experiment])

                if url.endswith('.bw') or url.endswith(".bed") or url.endswith(".bed.gz") or url.endswith(".hic"):

                    if genome_assembly not in track_results:
                        track_results[genome_assembly] = []

                    track_results[genome_assembly].append([url, project, genome_assembly, file_type, biosource, assay_info, replicate_info, dataset, description, lab, publications, accession, experiment, track_title, color, alt_color])




fname = output_folder + '/4dn_hic.txt'
with open(fname, 'w') as f:
    print('url\tProject\tAssembly\tBiosource\tAssay\tReplicate\tDataset\tDescription\tLab\tPublications\tAccession\tExperiment', file=f)
    for x in hic_results:
        print('\t'.join(x), file=f)

for key in track_results.keys():

    fname = output_folder + '/4dn_' + key + '_tracks.txt'
    with open(fname, 'w') as f:
        print('url\tProject\tAssembly\tType\tBiosource\tAssay\tReplicate\tDataset\tDescription\tLab\tPublications\tAccession\tExperiment\tname\tcolor\taltColor', file=f)
        for x in track_results[key]:
            print('\t'.join(x), file=f)
