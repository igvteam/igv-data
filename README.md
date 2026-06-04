# igv-data

Data, hubs, and genome definitions supporting [IGV](https://github.com/igvteam/igv), [igv.js](https://github.com/igvteam/igv.js), and [igv-webappp](https://github.com/igvteam/igv-webapp).

## Hosting IGV genome data for IGV desktop

Below are steps for setting up a host for IGV desktop genome data.  The instructions assume you have a server
with base url 'https://myGenomeServer/igv-data' to an 'igv-data' directory on the server.  Adjust step 3 as needed for 
your actual server url.

1. Clone this repository
2. Run the script 
   ```'update_base_url.sh https://myGenomeServer/igv-data```
3. Copy the 'data' and 'genomes' directory to the 'igv-data' directory on your server.

You should now have a server hosting the genome data for IGV desktop.  To use this server users will need to edit
the 'Genome server URL' on the Advanced tab of the IGV preferences window,  accessed from the "View > Preferences" menu.
The value of this property depends on the IGV version

* 3.0 and later:  genomes3.tsv
* 2.17 to 2.19: genomes2.tsv
* 2.11 to 2.16: legacy/genomes.tsv
* 2.10 and earlier: legacy/genomes.txt

Alternatively, in lieu of editing the genome server url interactively the following line can be added to the user's pref.properties file
located in the 'igv' folder under the user home directory.  Adjust the value for the IGV version as above.

```
IGV.genome.sequence.dir=https://myGenomeServer/igv-data/genomes3.tsv
```


Note: the hosted genome data files do not contain any sequence or annotation,  only configuration and meta data in the form of text and json files.   
These files reference sequence and annotation files hosted elsewhere, primarily the UCSC Genome Browser servers.



