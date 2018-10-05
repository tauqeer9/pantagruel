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

The pipeline can be run using a single interface to deploy the several arms of the pipeline.  
It first requires to initiate the *Pantagruel* database, i.e. giving it a name, creating the base file structure, defining main options.
The generic syntax is as follows:  
```sh
pantagruel -d db_name -r root_dir init ./init_file
```  
Then, the pipeline can be run step-by-step by performing each task in the following list **in order**:
```sh
pantagruel -d db_name -r root_dir TASK [task-specific options]
```
with `TASK` to be picked among the following (equivalent digit/number/keywords are separated by a '|'):
```
  0|00|fetch|fetch_data
       fetch public genome data from NCBI sequence databases and annotate private genomes
  1|01|homologous|homologous_seq_families
       classify protein sequences into homologous families
  2|02|align|align_homologous_seq
       align homologous protein sequences and translate alignemnts into coding sequences
  3|03|sqldb|create_sqlite_db
       initiate SQL database and load genomic object relationships
  4|04|core|core_genome_ref_tree
       select core-genome markers and compute reference tree
  5|05|genetrees|gene_trees
       compute gene tree
  6|06|reconciliations
       compute species tree/gene tree reconciliations
  7|07|coevolution
       quantify gene co-evolution and build gene association network
  8|08|specific|clade_specific_genes
       classify genes into orthologous groups (OGs) and search clade-specific OGs

```  
For detail of task-specific options, please run:  
```sh
pantagruel -d db_name -r root_dir TASK help
```  
Alternatively, to run the whole pipeline at once, simply perform the `all` task:
```sh
pantagruel -d db_name -r root_dir all
```  

-------------

![repas]

-------------

## Installing Pantagruel and its dependencies

Under a Debian environment (e.g. Ubuntu), please follow the indications in the [INSTALL](https://github.com/flass/pantagruel/blob/master/INSTALL.md) page.  

Below is a summary of the software on which Pantagruel dependends:

### Required bioinformatic software
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
  
- **Python** (version 2.7, >=2.7.13 recommended) + packages:
  - [sqlite3](https://docs.python.org/2/library/sqlite3.html) (standard package in Python 2.7)
  - [scipy/numpy](https://www.scipy.org/scipylib/download.html)
  - [tree2](https://github.com/flass/tree2)
  - [BioPython](http://biopython.org/wiki/Download)
  - [Cython](https://pypi.org/project/Cython/)
  - [igraph](http://igraph.org/python/) (available as a Debian package)

### Other required software
- [sqlite3](https://www.sqlite.org) (available as a Debian package *sqlite3*)
- [LFTP](https://lftp.yar.ru/get.html) (available as a Debian package *lftp*)
- [(linux)brew](http://linuxbrew.sh/) (available as a Debian package *linuxbrew-wrapper*)
- [docker](https://www.docker.com/) (available as a Debian package *docker.io*)



[repas]: https://github.com/flass/pantagruel/blob/master/pics/Pantagruels_childhood.jpg
[pipeline1]: https://github.com/flass/pantagruel/blob/master/pics/extract_cluster_concat_spetree_MLgenetrees.png
[pipeline2]: https://github.com/flass/pantagruel/blob/master/pics/collapse_samplebackbones_reconcile_compare.png
