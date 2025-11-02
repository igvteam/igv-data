# Search the ENCODE webservice for data files IGV supports and create tables for each assembly and file type.  Data
# is split into 3 "types", signals, peaks, and other, to reduce the number of files in each table.
# This script creates plain text files in the "output" foloder.  To deploy the move to ../data/encode
#
# To create a list of .hic files, run the script with FORMATS = set(["hic"])

import requests
import os

FORMATS = set(["bigBed", "bigWig", "bedpe", "tsv", "vcf", "hic"])
#FORMATS = set(["hic"])

output_folder = "output"

if not os.path.isdir(output_folder):
    os.mkdir(output_folder)

# Force return from the server in JSON format
HEADERS = {'accept': 'application/json'}

URL = "https://www.encodeproject.org/search/?" \
      "type=Experiment&" \
      "format=json&" \
      "field=biosample_summary&" \
      "field=lab.title&" \
      "field=biosample_ontology.name&" \
      "field=assay_term_name&" \
      "field=target.title&" \
      "field=files.file_format&" \
      "field=files.output_type&" \
      "field=files.href&" \
      "field=files.technical_replicates&" \
      "field=files.biological_replicates&" \
      "field=files.assembly&" \
      "field=files.accession&" \
      "limit=all"

# GET the object
response = requests.get(URL, headers=HEADERS)

# Extract the JSON response as a python dict
response_json_dict = response.json()

# Graph object
graph = response_json_dict['@graph']

# Dicitionary for results

results = {}
hic_files = []

def listToString(l):
    result = ''
    for i in range(len(l)):
        if i > 0:
            result += ","
        result += str(l[i])
    return result


for record in graph:

    id = record["@id"]
    experiment = id[13:][:-1]
    if 'biosample_summary' in record:
        biosample = record['biosample_summary']
    else:
        biosample = ''
    assay_type = record['assay_term_name']
    lab = record['lab']['title']
    if 'target' in record:
        target = record['target']['title'].replace('(Homo sapiens)', '')
    else:
        target = ''

    # print(cell_type + '\t' + assay_type + '\t' + target)
    if 'files' in record:
        for file in record['files']:
            if 'assembly' in file and 'href' in file:
                assembly = file['assembly']
                format = file['file_format']
                output_type = file['output_type']
                accession = file['accession']

                bio_rep = ''
                tech_rep = ''
                if 'biological_replicates' in file:
                    bio_rep = listToString(file['biological_replicates'])

                if 'technical_replicates' in file:
                    tech_rep = listToString(file['technical_replicates'])

                if format == 'bigWig' or format == 'bw':
                    if assay_type.startswith('ChIP'):
                      key = assembly + '.signals.chip'
                    else:
                      key = assembly + '.signals.other'
                elif format == 'hic':
                    key = assembly + '.hic'
                else:
                    key = assembly + '.other'

                if key in results:
                    r = results[key]
                else:
                    r = []
                    results[key] = r

                if format in FORMATS:
                    r.append(id + '\t' + assembly + '\t' + biosample + '\t' + assay_type + '\t' + target + '\t' +
                             str(bio_rep) + '\t' + str(tech_rep) + '\t' + output_type + '\t' + format + '\t' +
                             lab + '\t' + file['href'] + '\t' + accession + '\t' + experiment)

for a in list(results):
    fname = output_folder + '/' + a + ".txt"
    with open(fname, 'w') as f:
        print(
            'ID\tAssembly\tBiosample\tAssayType\tTarget\tBioRep\tTechRep\tOutputType\tFormat\tLab\tHREF\tAccession\tExperiment',
            file=f)
        r = results[a]
        for x in r:
            print(x, file=f)

        fname = output_folder + '/' + a + ".txt"