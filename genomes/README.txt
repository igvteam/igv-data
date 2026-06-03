Files in this directory:

* genomes2.tsv - A tab-separated file listing IGV hosted genomes.  Used by versions 2.17  - 2.19 of the IGV desktop application.
* genomes3.tsv - A tab-separated file listing IGV hosted genomes.  Used by versions 3.0 and later of the IGV desktop application.
* publicHubs.json - A JSON file of public hubs from the UCSC API.  This is used as a backup when the UCSC server
is down.  To refresh this file run

         curl -o publicHubs.json https://api.genome.ucsc.edu/list/publicHubs