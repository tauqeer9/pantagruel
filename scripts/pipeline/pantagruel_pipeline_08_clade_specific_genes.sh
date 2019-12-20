#!/bin/bash

#########################################################
## PANTAGRUEL:                                         ##
##             a pipeline for                          ##
##             phylogenetic reconciliation             ##
##             of a bacterial pangenome                ##
#########################################################

# Copyright: Florent Lassalle (f.lassalle@imperial.ac.uk), 30 July 2018

if [ -z "$1" ] ; then echo "missing mandatory parameter: pantagruel config file" ; echo "Usage: $0 ptg_env_file" ; exit 1 ; fi
envsourcescript="$1"
source ${envsourcescript}

checkptgversion
checkfoldersafe ${orthogenes}

###############################################
## 08. orthologous and clade-specific gene sets
###############################################

cd ${ptgrepo} ; export ptgversion=$(git log | grep commit | cut -d' ' -f2) ; cd -

# classify genes into orthologous groups for each gene of the reconciled gene tree sample
# do not report detailed results but, using gptgh analysis, combine the sample-wide classification into one classification for the gene family
# run in parallel

## for the moment only coded for dated ALE model (ALEml reconciliations)
## and with no colpased gene tree clades (need to discard events below replacement clade subtree roots [as in parse_collapsedALE_scenarios.py]
## and to transpose orthologus group classification of collapsed clade to member genes)

if [ -z ${getOrpthologuesOptions} ] ; then
  getOrpthologuesOptions=" --ale.model=${rectype} --methods='mixed' --max.frac.extra.spe=0.5 --majrule.combine=0.5 --colour.combined.tree --use.unreconciled.gene.trees ${mbgenetrees} --unreconciled.format 'nexus' --unreconciled.ext '.con.tre'"
fi
if [ -z ${orthocolid} ] ; then
  orthocolid=1
fi
# derived parameters
if [ ${ALEalgo} == 'ALEml_undated' ] ; then
  export rectype='undat'
else
  export rectype='dated'
fi

# safer specifying the reconciliation collection to parse; e.g.: 'ale_collapsed_dated_1'
if [ -z "${reccol}" ] ; then
  # if not inferred from the record of the last reconciliation computation
  reccol=$(cut -f4 ${alerec}/reccol)
  [ -z "${reccol}" ] && echo "Error: cannot find reconciliation collection as env variable \$reccol is empty; exit now" ; exit 1
fi

outrecdir=${recs}/${collapsecond}/${replmethod}/${reccol}

# generate ortholog collection
step1="generating ortholog collection from reconciled gene trees"
echo ${step1}
orthocol=ortholog_collection_${orthocolid}
mkdir -p ${orthogenes}/${orthocol}
${ptgscripts}/get_orthologues_from_ALE_recs.py -i ${outrecdir} -o ${orthogenes}/${orthocol} ${getOrpthologuesOptions} &> $ptglogs/get_orthologues_from_ALE_recs_${orthocol}.log
checkexec "step 1: failed when ${step1}" "step 1: complete ${step1}"

# import ortholog classification into database
step2="importing ortholog classification into database"
echo ${step2}
sqlite3 ${sqldb} """INSERT INTO ortholog_collections (ortholog_col_id, ortholog_col_name, reconciliation_id, software, version, algorithm, ortholog_col_date, notes) VALUES 
(${orthocolid}, '${orthocol}', ${parsedreccolid}, 'pantagruel/scripts/get_orthologues_from_ALE_recs.py', '${ptgversion:0:7}', 'getOrthologues(method=''mixed'')', '$(date +%Y-%m-%d)', 
'source from https://github.com/flass/pantagruel/commits/${ptgversion}, call: ''scripts/get_orthologues_from_ALE_recs.py ${getOrpthologuesOptions}''')
;
"""
python2.7 ${ptgscripts}/pantagruel_sqlitedb_load_orthologous_groups.py ${sqldb} ${orthogenes}/${orthocol} "mixed" "majrule_combined_0.500000" ${orthocolid}
checkexec "step 2.1: failed when ${step2} for reconciled gene trees" "step 2.1: completed ${step2} for reconciled gene trees"
python2.7 ${ptgscripts}/pantagruel_sqlitedb_load_orthologous_groups.py ${sqldb} ${orthogenes}/${orthocol} "unreconciled" "unicopy" ${orthocolid} 1
checkexec "step 2.2: failed when ${step2} for unreconciled gene trees" "step 2.2: completed ${step2} for unreconciled gene trees"

# generate abs/pres matrix
step3="generating abs/pres matrix"
echo ${step3}
orthocol=ortholog_collection_${orthocolid}
echo ${orthocol}
orthomatrad=${orthogenes}/${orthocol}/mixed_majrule_combined_0.5.orthologs
python2.7 ${ptgscripts}/get_ortholog_presenceabsence_matrix_from_sqlitedb.py ${sqldb} ${orthomatrad} ${orthocolid}
checkexec "step 3: failed ${step3}" "step 3: completed ${step3}"

# create clsutering based on the abs/pres matrix (using Jaccard Distance)
${dbscripts}/pangenome_hclust.r ${orthomatrad} 1000 & 

# list clade-specific orthologs
step4="listing clade-specific orthologs"
echo ${step4}
${ptgscripts}/get_clade_specific_genes.r ${orthomatrad}_genome_counts.no-singletons.mat ${sqldb} ${orthocolid} ${speciestree} ${orthomatrad}
${ptgscripts}/get_clade_specific_genes.r --gene_count_matrix ${orthomatrad}_genome_counts.no-singletons.mat \
 --sqldb ${sqldb} --og_col_id ${orthocolid} --clade_defs ${cladedefs} \
 --outrad ${orthomatrad} &> ${raplogs}/get_clade_specific_genes.log
 checkexec "step 4: failed ${step4}" "step 4: completed ${step4}"

## test GO term enrichment in gene sets

## generate background term distribution for clades i.e. list all genes in their pangenome and associated terms
step5="generating background term distribution for clades"
echo ${step5}
export goterms=${funcannot}/GeneOntology
mkdir -p ${goterms}
# for the whole dataset
sqlite3 -cmd ".mode tab" ${sqldb} "select distinct locus_tag, go_id from coding_sequences 
left join functional_annotations using (nr_protein_id) 
left join interpro2GO using (interpro_id) ;" > ${goterms}/${ngenomes}-genomes_pangenome_terms.tab
# for all clades of the species tree
export claderefgodir=${goterms}/clade_go_term_reference_sets
mkdir -p ${claderefgodir}/
tail -n +2 ${cladedefs} | while read cla cladedef siscladedef ; do
  claspeset="'$(echo $cladedef | sed -e "s/,/','/g")'"
  echo $cla $claspeset
  cladest=${claderefgodir}/${cla}_pangenome_terms.tab
  q="select distinct locus_tag, go_id from coding_sequences 
  inner join replicons using (genomic_accession)
  inner join assemblies using (assembly_id)
  left join functional_annotations using (nr_protein_id) 
  left join interpro2GO using (interpro_id) 
  where code in (${claspeset})"
  sqlite3 -cmd ".mode tab" ${sqldb} "${q};" > ${cladest}
  checkexec "step 5: failed ${step5} for clade ${cla} including NULL go_id"
  sqlite3 -cmd ".mode tab" ${sqldb} "${q} and go_id not null;" > ${cladest}_nonull
  checkexec "step 5: failed ${step5} for clade ${cla} not including NULL go_id"
  ls -lh ${cladest}
done
checkexec "step 5: failed ${step5}" "step 5: completed ${step5}"

export dirgotablescladespe=${orthomatrad}_specific_genes.tables_byclade_goterms_pathways
export dirgoenrichcladespecore=${goterms}/clade_go_term_enriched_cladespecific_vs_coregenome
mkdir -p ${dirgoenrichcladespecore}/
# compare each clade-specific core genome (single repr sequence per OG) to its respective core genome (single repr sequence per OG)
step6="comparing each clade-specific core genome to its respective core genome"
echo ${step6}
tail -n +2 ${cladedefs} | while read cla name cladedef siscladedef maxabs maxpres ; do
  echo $cla
  cladspego=${dirgotablescladespe}/mixed_majrule_combined_0.5.orthologs_specific_genes_${cla}_reprseq_goterms.tab
  cut -f5,6 ${cladspego} | grep -v "NA$" > ${cladspego}_nonull
  ${dbscripts}/clade_specific_genes_GOterm_enrichment_test.r \
  --study_annots ${cladspego}_nonull  \
  --population_annots ${claderefgodir}/${cla}_coregenome_terms.tab_nonull \
  --out ${dirgoenrichcladespecore}/${cla}_go_term_enriched_cladespecific_vs_coregenome.tab \
  --algo "weight01" --stat "Fisher" &> ${raplogs}/clade_specific_vs_coregenome_${cla}_GOterm_enrichment_test.log
  checkexec "step 6: failed ${step6} for clade ${cla}"
  ls -lh ${dirgoenrichcladespecore}/*_${cla}_* ; echo ""
done &> ${raplogs}/cladespecific_vs_coregenome_genes_GOterm_enrichment_test.log
checkexec "step 6: failed ${step6}" "step 6: completed ${step6}"

export dirgotablescladespe=${orthomatrad}_specific_genes.tables_byclade_goterms_pathways
export dirgoenrichcladespepan=${goterms}/clade_go_term_enriched_cladespecific_vs_pangenome
mkdir -p ${dirgoenrichcladespepan}/
# compare each clade-specific core genome (all sequences) to its respective pangenome (all sequences)
step7="comparing each clade-specific core genome to its respective pangenome"
echo ${step7}
tail -n +2 ${cladedefs} | while read cla name cladedef siscladedef maxabs maxpres ; do
  echo $cla
  cladspego=${dirgotablescladespe}/mixed_majrule_combined_0.5.orthologs_specific_genes_${cla}_allseq_goterms.tab
  cut -f5,6 ${cladspego} | grep -v "NA$" > ${cladspego}_nonull
  ${dbscripts}/clade_specific_genes_GOterm_enrichment_test.r \
  --study_annots ${cladspego}_nonull  \
  --population_annots ${claderefgodir}/${cla}_pangenome_terms.tab_nonull \
  --out ${dirgoenrichcladespepan}/${cla}_go_term_enriched_cladespecific_vs_pangenome.tab \
  --algo "weight01" --stat "Fisher" &> ${raplogs}/clade_specific_vs_coregenome_${cla}_GOterm_enrichment_test.log
  checkexec "step 7: failed ${step7} for clade ${cla}"
  ls -lh ${dirgoenrichcladespepan}/*${cla}* ; echo ""
done &> ${raplogs}/cladespecific_vs_pangenome_genes_GOterm_enrichment_test.log
checkexec "step 7: failed ${step7}" "step 7: completed ${step7}"

# concatenate summary reports
step8="concatenating summary reports"
tail -n +2 ${cladedefs} | while read cla name cladedef siscladedef maxabs maxpres ; do
  cla=clade${n}
  echo "# ${cla} ${name}"
  echo "# cladespe vs. core"
  cat ${dirgoenrichcladespecore}/${cla}_go_term_enriched_cladespecific_vs_coregenome.tab
  echo "# cladespe vs. pan"
  cat ${dirgoenrichcladespepan}/${cla}_go_term_enriched_cladespecific_vs_pangenome.tab
  echo "# - - - "
done > ${goterms}/clade_go_term_enriched_cladespecific_summary.tab
checkexec "step 8: failed ${step8}" "step 8: completed ${step8}"
