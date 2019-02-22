# *Pantagruel*: a bioinformatic pipeline for the inference of gene evolution scenarios in bacterial pangenomes.

## Aim and description
*Pantagruel* provides an all-in-one software solution to reconstruct the complex evolutionary process of diversification of bacterial genomes.  

From a dataset of bacterial genomes, builds a database that describes the homology structure of all genes in the dataset -- the pangenome. With that, *Pantagruel* will first generate two key outputs:  
- a **reference (species) tree**, depicting the main signal of evolutionary relationships between input *genomes*;  
- **gene trees**, depicting the evolutionary relationships between gene sequences within a family of homologous genes.   

![pipeline1]

A **scenario of gene evolution** is inferred for each gene family in the dataset by reconciling the topology of gene trees with the reference species tree in a probabilistic framework.  

Such scenario describes the likely events of gene **duplication, horizontal transfer and loss** (DTL model) that marked the gene family history. These events are annotated on the branch of the gene tree and the of the reference tree, and make their history consistent.
From these annotations, one can derive the history of gain and loss of this gene over the reference tree of species, and follow the diversification of *gene lineages* within and across *genome lineages*.  

Gene tree/species tree reconciliation methods rely on the best available information to infer such scenarios, as they account for the phylogeny of genes; a probablilistic method is chosen to quantify the statistical support for inferences, in face of the large space of possible scenario and of the uncertainty in the input gene phylogeny.  
While probablilistic reconciliation methods are computationally costly, this pipeline uses innovative phylogenetic apporoaches based on the reduction of gene trees to their informative backbone that allow their use in a resonable time on **datasets of 1,000+ bacterial genome** and covering **multiple species**.

![pipeline2]


These historical data are then gathered in the database, which provides a way to:  
- quantify gene-to-gene association on the basis of their *co-evolution* signal at the gene lineage level;  
- classify genes into *orthologous clusters* based on the gain/loss scenarios, from which one can define *clade-specific gene sets*.  

Two version of the pipeline are distributed:  

- a script version, which source code is adaptable and can be deployed on high-performance computing (HPC) "cluster" Linux systems;  

- (in development) a pre-compiled Docker image that can be deployed on pretty much any platform, including swarms of virtual machines (VMs). The latter version was implemented using Philippe Veber's [Bistro](https://github.com/pveber/bistro) framework.

See below for instruction on software [installation](https://github.com/flass/pantagruel#installing-pantagruel-and-its-dependencies) and [usage](https://github.com/flass/pantagruel#using-pantagruel).

--------------------

## Using Pantagruel

### Tasks

The pipeline can be run using a single interface to deploy the several arms of the pipeline.  
It first requires to initiate the *Pantagruel* database, i.e. giving it a name, creating the base file structure, defining main options.
The generic syntax at the init stage is as follows, passing the key parameters using options:  
```sh
pantagruel -d db_name -r root_dir [other options] init
```  
Alternatively, the various parameters can be set directly in a Pantagruel configuration file specified with option `-i`:
```sh
pantagruel -d db_name -r root_dir -i config_file init
```  
the configuration file `config_file` can be generated by editing **a copy** of the [template environment script](https://github.com/flass/pantagruel/blob/master/scripts/pipeline/environ_pantagruel_template.sh). Note than it is only safe to edit the top parameters.

Then, the pipeline can be run step-by-step by performing a specified task:
```sh
pantagruel -i config_file TASK
```
with `TASK` to be picked among the following (equivalent digit/number/keywords are separated by a `|`):
```
  0|00|fetch|fetch_data
       fetch public genome data from NCBI sequence databases and annotate private genomes
  1|01|homologous|homologous_seq_families
       classify protein sequences into homologous families
  2|02|align|align_homologous_seq
       align homologous protein sequences and translate alignemnts into coding sequences
  3|03|sqldb|create_sqlite_db
       initiate SQL database and load genomic object relationships
  4|04|functional|functional_annotations
       use InterProScan to functionally annotate proteins in the database, including with Gene Ontology and metabolic pathway terms
  5|05|core|core_genome_ref_tree
       select core-genome markers and compute reference tree
  6|06|genetrees|gene_trees
       compute gene tree
  7|07|reconciliations
       compute species tree/gene tree reconciliations
  8|08|specific|clade_specific_genes
       classify genes into orthologous groups (OGs) and search clade-specific OGs
  9|09|coevolution
       quantify gene co-evolution and build gene association network

```  

Alternatively, several tasks ca be run at once by providing a space-separated string of tasks identifiers:  
```sh
pantagruel -i config_file TASK1 TASK2 ...
```
Finally, it is possible to run the whole pipeline at once, simply perform the `all` task:
```sh
pantagruel -i config_file all
```  

Note there are **dependencies between tasks**, which must be carried on mostly sequentially:  
- *00, 01, 02, 03 tasks* each strictly depend on the previous step: 00 -> 01 -> 02 -> 03  
- *functional annotation task 04* is optional - though highly recomended - and depends on the previous task 01: 01 -> 04 
- *reference tree task 05* depends on previous *task 03* (and thus the previous ones)  
- *gene trees task 06* only depends on the previous *task 03* (and thus the previous ones) **IF** the `-c|--collapse` option is **NOT** used: 03 -> 06  
- however, if the `-c` option is specified, *task 06* (specifically step 6.4 when in HPC mode) is also dependent on *task 05*: 03 + 05 -> 06  
- *gene tree/species tree reconciliation task 07* strictly depends on the previous steps: 05 + 06 -> 07  
- *orthologous group clustering task 08* depends on previous *reconciliation step 07*: 07 -> 08  
- *co-evolution network task 09* depends on previous *reconciliation task 07*: 07 -> 09  
- but if run after *task 08*, an additional version of the co-evolution network will be made by collapsing the full network, grouping gene nodes by orthologous group: 07 + 08 -> 09

So all in all, you're better off running all the tasks sequentially, for instance using `pantagruel all`.

### Options

Options are detailed here:  
```
# for Pantagruel task 0-9: only one _mandatory_ option:

    -i|--initfile     Pantagruel configuration file
                        this file is generated at init stage, from the specified options.

# for Pantagruel task init:

  _mandatory options_

    -d|--dbname       database name

    -r|--rootdir      root directory where to create the database; defaults to current folder

  _facultative options_

    -i|--initfile     Pantagruel configuration file
                        a file can be derived (i.e. manualy curated) from 'environment_pantagruel_template.sh' template.
                        Parameters values specified in this file will override other options

    -p|--ptgrepo      location of pantagruel software head folder; defaults to where is located the pantagruel executable (if a link, the location of its last target)

    -I|--iam          database creator identity (e-mail address is preferred)

    -f|--famprefix    alphanumerical prefix (no number first) of the names for homologous protein/gene family clusters; defaults to 'PANTAG'
                       the chosen prefix will be appended with a 'P' for protein families and a 'C' for CDS families.

    -T|--taxonomy      path to folder of taxonomy database flat files; defaults to $rootdir/NCBI/Taxonomy_YYYY-MM-DD (suffix is today's date)
                        if this is not containing the expected file, triggers downloading the daily dump from NCBI Taxonomy at task 00

    -A|--refseq_ass  path to folder of source genome assembly flat files formated like NCBI Assembly RefSeq whole directories;
                       these can be obtained by searching https://www.ncbi.nlm.nih.gov/assembly and downloadingresults with options:
                         Source Database = 'RefSeq' and File type = 'All file types (including assembly-structure directory)'.
                       defaults to $rootdir/NCBI/Assembly_YYYY-MM-DD (suffix is today's date). 
                       A simple archive 'genome_assemblies.tar' (as obtained from the NCBI website)can be placed in that folder.
                       If user genomes are also provided, these RefSeq assemblies will be used as reference for their annotation.

    --refseq_ass4annot idem, but WILL NOT be used in the study, only as a reference to annotate user genomes (defaults to vaule of -A option)

    -a|--custom_ass  path to folder of user-provided genomes (defaults to $rootdir/user_genomes), containing:
                      _mandatory_ 
                       - a 'contigs/' folder, where are stored multi-FASTA files of genome assemblies (one file per genome,
                          with extension '.fa', '.fasta' or '.fas' ...). Fasta file names will be truncated by removing
                          the '.fa' string and everything occuring after) and will be retained as the assembly_id (beware 
                          of names redundant with RefSeq assemblies).
                       - a 'strain_infos.txt' file describing the organism, with columns headed:
                           'sequencing_project_id'; 'genus'; 'species'; 'strain'; 'taxid'; 'locus_tag_prefix'
                         'sequencing_project_id' must match the name of a contig file (e.g. 'seqProjID.fasta')
                         'locus_tag_prefix' must match the prefix of ids given to CDS, proteins and genome regions (contigs)
                         in potentially provided annotation files (see below).
                      _optional_ 
                       - an 'annotation/' folder, where are stored annotation files: 
                         - one mandatory in GFF 3.0 file format (with a '.gff' extension);
                          and optionally, the following files (with consistent ids!!):
                         - one in GenBank flat file format (with a '.gbk' extension);
                         - one in Fasta format containing CDS sequences (with a '.ffn' extension).
                         - one in Fasta format containing matching protein sequences (with a '.faa' extension).
                         These four files are produced when using Prokka for annotation; if at least one of the .gbk, .ffn or .faa
                         are missing, all three will be derived from the .gff source. Each genome annotation file set must be stored
                         in a separate folder, which name must match a contig file (e.g. 'seqProjID/' for 'seqProjID.fasta').
                      NOTE: to ensure proper parsing, it is strongly advised that any provided annotation was generated with Prokka
                      NOTE: to ensure uniform annotation of the dataset, it is advised to let Pantagruel annotate the contigs (calling Prokka)

    -s|--pseudocore  integer or string, the minimum number of genomes in which a gene family should be present to be included in
                       the pseudo-core genome, i.e. the gene set which alignments will be concatenated for reference tree search.
                       Only relevant when running task 'core'; a non-integer value will trigger an INTERACTIVE prompt for search of an optimal value.
                       Defaults to the total number of genomes (work with a strict core genome set).

    -t|--reftree     specify a reference tree for reconciliation and clade-specific gene analyses;
                       over-rides the computation of tree from the concatenate of (pseudo-)core genome gene during taske 'core'.

    --core_seqtype   {cds|prot} define the type of sequence that will be used to compute the (pseudo-)core genome tree (default to 'cds')

    --pop_lg_thresh  definee the threshold of branch length for delinating populations in the reference tree 
                       (default: 0.0005 for nucleotide alignemnt-based tree; 0.0002 for protein-based)

    --pop_bs_thresh  definee the threshold of branch support for delinating populations in the reference tree (default: 80)

    -R|--resume      try and resume the task from previous run that was interupted (for the moment only available for taske 'core')

    -H|--submit_hpc  full address (hostname:/folder/location) of a folder on a remote high-performance computating (HPC) cluster server
                       This indicate that computationally intensive tasks, including building the gene tree collection
                       ('genetrees') and reconciling gene tree with species tree ('reconciliations') will be run
                       on a HPC server (only Torque/PBS job submission system is supported so far).
                       [support for core genome tree building ('core') remains to be implemented].
                       Instead of running the computations, scripts for cluster job submission will be generated automatically.
                       Data and scripts will be transfered to the specified address (the database folder structure
                       will be duplicated there, but only relevant files will be synced). Note that job submission
                       scripts will need to be executed manually on the cluster server.
                       If set at init stage, this option will be maintained for all tasks. However, the remote address
                       can be updated when calling a specific task; string 'none' cancels the HPC behaviour.

    -c|--collapse      enable collapsing the rake clades in the gene trees (strongly recomended in datasets of size > 50 genomes).

    -C|--collapse_par  [only for 'genetrees' task] specify parameters for collapsing the rake clades in the gene trees.
                       A single-quoted, semicolon-delimited string containing variable definitions must be provided.
                       Default is equivalent to providing the following string:
                          'cladesupp=70 ; subcladesupp=35 ; criterion=bs ; withinfun=median'


# for any Pantagruel command calls:

    -h|--help          print this help message and exit.
```  

### Usage example  
Here is a standard examples of using `pantagruel` program.

First, to create a *new* database, we need to run the `init` task. To pass the key parameters, including where to create the database and its name, we will be using options:
```sh
pantagruel -d databasename -r /root/folder/for/database -f PANTAGFAM -I f.lassalle@imperial.ac.uk -A /folder/of/public/genome/in/RefSeq/format init
```  
Then, to actually run the pipeline, we will execute the following tasks. At this stage, no options need to (or can) be specified trough the command line, as all parameters are already defined
following the database intitiation stage (see above) and were stored in a configuration file. You will now simply have to specify where to find this configuration file with the `-i` option.
Unless you moved it, the configuration file should be where it has been created automatically,
at `${root_dir}/${db_name}/environ_pantagruel_${db_name}.sh`, with `${db_name}` and `${root_dir}` the arguments of `-d` and `-r` options on the `pantagruel init` call.
So in our case, to execute the first three tasks, up to gene family sequence alignement, you can type the following command:  
```sh
pantagruel -i /root/folder/for/database/databasename/environ_pantagruel_databasename.sh fetch homologous align
```  
Note that this config file can be edited in-between tasks, for instance to change the location of key input files that you moved, or to tweak paramters - however this may cause issues in task dependencies (see above).

-------------

## Installing Pantagruel and its dependencies

Under a Debian environment (e.g. Ubuntu), please follow the indications in the [INSTALL](https://github.com/flass/pantagruel/blob/master/INSTALL.md) page.  

Below is a summary of the software on which Pantagruel dependends:

### Required bioinformatic software
- **Prokka** for genome annotation
  (Install from  [source code](https://github.com/tseemann/prokka); )

- **MMseqs2/Linclust** for homologous sequence clustering  
  (Install from [source code](https://github.com/soedinglab/MMseqs2); last tested version https://github.com/soedinglab/MMseqs2/commit/c92411b91175a2362554849b8889a5770a1ae537)

- **Clustal Omega** for homologous sequence alignment  
  (Install from [source code](http://www.clustal.org/omega/) or *clustalo* debian package; version used and recommended: 1.2.1)  
  - \[ future development: consider using [FAMSA](http://sun.aei.polsl.pl/REFRESH/famsa) \]

- **PAL2NAL** for reverse tanslation of protein sequence alignments into CDS alignments  
  ([Perl source code](http://www.bork.embl.de/pal2nal/))

- **RAxML** for species tree and initial (full) gene tree estimation  
  (Install from [source code](https://github.com/stamatak/standard-RAxML) or *raxml* debian package; version used and recommended: 8.2.9)  
  - \[ future development: consider using RAxML-NG (Install from [source code](https://github.com/amkozlov/raxml-ng)) \]

- **MrBayes** for secondary estimation of (collapsed) gene trees  
  (Install from [source code](http://mrbayes.sourceforge.net/) or *mrbayes* and *mrbayes-mpi* debian packages; version used and recommended: 3.2.6)  
  - \[ future development: consider using [RevBayes](http://revbayes.github.io/) \]

- **MAD** for species tree rooting  
  ([R source code](https://www.mikrobio.uni-kiel.de/de/ag-dagan/ressourcen/mad-r-tar.gz))

- **ALE/xODT** for gene tree / species tree reconciliation  
  (Install from [source code](https://github.com/ssolo/ALE); version used and recommended: 0.4; notably depends on [Bio++ libs](https://github.com/BioPP) (v2.2.0))
  
### Required code libraries
- **R** (version 3, >=3.2.3 recommended) + packages:
  - ape
  - phytools
  - vegan
  - ade4
  - igraph
  - getopt
  - parallel
  - DBI, RSQLite
  - topGO (optional)
  - pvclust (optional)
  
- **Python** (version 2.7, >=2.7.13 recommended) + packages:
  - [sqlite3](https://docs.python.org/2/library/sqlite3.html) (standard package in Python 2.7)
  - [scipy/numpy](https://www.scipy.org/scipylib/download.html)
  - [tree2](https://github.com/flass/tree2)
  - [BioPython](http://biopython.org/wiki/Download)
  - [BCBio.GFF](https://pypi.org/project/bcbio-gff)
  - [Cython](https://pypi.org/project/Cython/)
  - [igraph](http://igraph.org/python/) (available as a Debian package)

### Other required software
- [sqlite3](https://www.sqlite.org) (available as a Debian package *sqlite3*)
- [LFTP](https://lftp.yar.ru/get.html) (available as a Debian package *lftp*)
- [(linux)brew](http://linuxbrew.sh/) (available as a Debian package *linuxbrew-wrapper*)
- [docker](https://www.docker.com/) (available as a Debian package *docker.io*)
- [JAVA Runtime (JDK 8.0)](https://openjdk.java.net) (available as Debian packages *openjdk-8-jdk* and *openjdk-8-jre*)
- [CD-HIT](https://cd-hit.org) (available as a Debian package *cd-hit*)
- [bioperl](https://bioperl.org) (available as a Debian package *bioperl*)

-------------

![repas]


[repas]: https://github.com/flass/pantagruel/blob/master/pics/Pantagruels_childhood.jpg
[pipeline1]: https://github.com/flass/pantagruel/blob/master/pics/extract_cluster_concat_spetree_MLgenetrees.png
[pipeline2]: https://github.com/flass/pantagruel/blob/master/pics/collapse_samplebackbones_reconcile_compare.png
