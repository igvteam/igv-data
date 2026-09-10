# igv-data

Data, hubs, and genome definitions supporting [IGV](https://github.com/igvteam/igv), [igv.js](https://github.com/igvteam/igv.js), and [igv-webappp](https://github.com/igvteam/igv-webapp).

The genome definitions and hubs in this repository reference each other by their
raw.githubusercontent.com URLs, so a checkout works as is.  A copy served from another
host needs those URLs repointed at that host, which is what 'scripts/buildMirror.sh' does.
This is how https://igv.org/genomes is maintained -- it exists for sites that are
unwilling to whitelist raw.githubusercontent.com.

## Hosting the genome data

Below are steps for setting up a host for the genome data.  The instructions assume you have a server
with base url 'https://myGenomeServer/igv-data' to an 'igv-data' directory.  Adjust step 2 as needed for
your actual server url.

1. Download 'scripts/buildMirror.sh' and 'scripts/verifyMirror.py' from this repository
2. Run it

   ```buildMirror.sh /tmp/mirror https://myGenomeServer/igv-data```

3. Check it, which follows the genome lists and the hubs they reference

   ```verifyMirror.py /tmp/mirror https://myGenomeServer/igv-data```

4. Copy the 'genomes' directory written to /tmp/mirror to the 'igv-data' directory on
   your server.

The script needs nothing but curl and tar: it downloads the current 'genomes' tree as a
tarball published by the 'genomes tarball' workflow, at

```
https://github.com/igvteam/igv-data/releases/download/genomes-latest/genomes.tar.gz
```

and repoints the URLs in it at the host given on the command line.  Run it from a checkout
with '--local' to mirror work that is not pushed yet, or with '--ref <ref>' for a particular
branch or tag; both use git rather than the download.

To refresh a mirror later, run the same command with '--update'.  Without that option an
existing mirror is left alone, so a mistyped output directory cannot damage one.  The script
never deletes anything: the files in the new tree replace their counterparts, and everything
else in the mirror, including files the site has added itself, is left as it is.

The genome lists ('genomes2.tsv', 'genomes3.tsv', the four under 'legacy', and
'web/genomes.json') are included.  They rarely change, so '--no-lists' leaves them out of the
mirror; they are not unpacked at all, so on an update the deployed copies are untouched.

Only URLs that point into the mirrored tree are rewritten.  Two kinds of reference are left
alone:

* Sequence and annotation files under https://igv.org/genomes/data, which are not part of this
  repository.
* A handful of references into the repository's own top level 'data' directory -- tutorial
  tracks and an alias file -- which the tarball does not include.  These stay on
  raw.githubusercontent.com; igv.org serves the same tree at https://igv.org/data.  A site
  that cannot reach raw.githubusercontent.com at all needs that directory copied from a
  checkout and those URLs rewritten as well.

You should now have a server hosting the genome data.  What clients do with it is described below.

## Using the mirror

### IGV desktop

Users point the 'Genome server URL' on the Advanced tab of the IGV preferences window, accessed
from the "View > Preferences" menu, at the genome list file in the mirror.  Which list file
depends on the IGV version -- they are described in 'genomes/README.txt', and for versions
older than 2.17 in 'genomes/legacy/readme.txt'.  For IGV 3.0 and later that is 'genomes3.tsv':

```
https://myGenomeServer/igv-data/genomes/genomes3.tsv
```

Alternatively, in lieu of editing the genome server url interactively the following line can be added to the user's pref.properties file
located in the 'igv' folder under the user home directory.  Adjust the value for the IGV version as above.

```
IGV.genome.sequence.dir=https://myGenomeServer/igv-data/genomes/genomes3.tsv
```

### igv.js and igv-webapp

Point the "genomes" property of the igv.js configuration at the genome list in the mirror:

```
const config = {
    genomes: "https://myGenomeServer/igv-data/genomes/web/genomes.json",
    ...
}
```

igv-webapp takes the same property in its own configuration.


Note: the hosted genome data files do not contain any sequence or annotation,  only configuration and meta data in the form of text and json files.   These files reference sequence and annotation files hosted elsewhere, primarily the UCSC Genome Browser servers.
