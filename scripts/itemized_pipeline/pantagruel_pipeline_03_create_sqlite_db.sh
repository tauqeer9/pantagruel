#!/bin/bash

#########################################################
## PANTAGRUEL:                                         ##
##             a pipeline for                          ##
##             phylogenetic reconciliation             ##
##             of a bacterial pangenome                ##
#########################################################

# Copyright: Florent Lassalle (f.lassalle@imperial.ac.uk), 30 July 2018

export raproot=$1
envsourcescript=${raproot}/environ_pantagruel.sh
source $envsourcescript

##############################################
## 03. Create and Populate SQLite database
##############################################

export database=${rapdb}/03.database
export sqldbname=${rapdbname,,}
export sqldb=${database}/${sqldbname}
mkdir -p ${database}
cd ${database}
### create and populate SQLite database

## Genome schema: initiate and populate
${ptgscripts}/pantagruel_sqlite_genome_db.sh ${database} ${sqldbname} ${genomeinfo}/metadata_${rapdbname} ${genomeinfo}/assembly_info ${protali} ${protfamseqs}.tab ${protorfanclust} ${cdsorfanclust} ${straininfo}

# dump reference table for translation of genome assembly names into short identifier codes (uing UniProt "5-letter" code when available).
sqlite3 ${sqldb} "select assembly_id, code from assemblies;" | sed -e 's/|/\t/g' > ${database}/genome_codes.tab
sqlite3 ${sqldb} "select code, organism, strain from assemblies;" | sed -e 's/|/\t/g' > ${database}/organism_codes.tab
# and for CDS names into code of type "SPECIES_CDSTAG" (ALE requires such a naming)
# here split the lines with '|' and remove GenBank CDS prefix that is always 'lcl|'
sqlite3 ${sqldb} "select genbank_cds_id, cds_code from coding_sequences;" | sed -e 's/lcl|//g'  | sed -e 's/|/\t/g' > ${database}/cds_codes.tab

# translates the header of the alignment files
export protalifastacodedir=${protali}/full_protfam_alignments_species_code
export cdsalifastacodedir=${protali}/full_cdsfam_alignments_species_code
for mol in prot cds ; do
  alifastacodedir=${protali}/full_${mol}fam_alignments_species_code
  mkdir -p ${alifastacodedir}
  eval "export ${mol}alifastacodedir=${alifastacodedir}"
  # use multiprocessing python script
  ${ptgscripts}/lsfullpath.py ${protali}/full_${mol}fam_alignments .aln > ${protali}/full_${mol}fam_alignment_list
  ${ptgscripts}/genbank2code_fastaseqnames.py ${protali}/full_${mol}fam_alignment_list ${database}/cds_codes.tab ${alifastacodedir} > ${rapdb}/logs/genbank2code_fastaseqnames.${mol}.log
done

## Phylogeny schema: initiate
sqlite3 ${dbfile} < $ptgscripts/pantagruel_sqlitedb_phylogeny_initiate.sql