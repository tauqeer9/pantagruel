#!/bin/bash

#########################################################
## PANTAGRUEL:                                         ##
##             a pipeline for                          ##
##             phylogenetic reconciliation             ##
##             of a bacterial pangenome                ##
#########################################################

# Copyright: Florent Lassalle (f.lassalle@imperial.ac.uk), 30 July 2018

if [ -z "$1" ] ; then echo "missing mandatory parameter: pantagruel config file" ; echo "Usage: $0 ptg_env_file [gene_fam_list]" ; exit 1 ; fi
envsourcescript="$1"
source ${envsourcescript}

if [ ! -z "$2" ] ; then
  export genefamlist="$2"
fi

checkptgversion
checkfoldersafe ${alerec}

if [ -z "${ptgthreads}" ] ; then
  export ptgthreads=$(nproc)
fi

###############################################
## 07. Gene tree / Species tree reconciliations
###############################################

######################################################
## 07.1 Infer Gene tree / Species tree reconciliations
######################################################

### perform reconciliations with GeneRax, meaning the gene tree toppology is jointly optimized with the gene family evolution scenario

# parameters to be set:
#~ export recsamplesize=1000
if [ -z ${reccolid} ] ; then
 reccolid=1
fi
# derived parameters
if [[ "${GeneRaxalgo}" =~ 'reconciliation-samples' ]] ; then
  export rectype='recsampling'
else
  export rectype='pointestimate'
fi
export reccol="generax_${chaintype}_${rectype}_${reccolid}"
export recs=${alerec}/${chaintype}_GeneRax_recs
export reccoldate=$(date +%Y-%m-%d)

gttorecdir=${coltreechains}/${collapsecond}/${replmethod}
grxlogs=${ptgdb}/logs/GeneRax
mkdir -p ${grxlogs}/${reccol}
export outrecdir=${recs}/${collapsecond}/${replmethod}/${reccol}
mkdir -p ${outrecdir}

# recording the software version that was used
GRheader="$(${grbin} -h | grep '\[00:00:' | awk '{ print $2,$3 }')"
if [ -z "${GRheader}" ] ; then
  GRheader="GeneRax"
fi
GRvtag=$(echo ${GRheader} | awk '{ print $NF }')
	
if [[ ! -z "${grbin}" ]] ; then
  pathgrbin=$(readlink -f "${grbin}")
  grrepo=${pathgrbin%%GeneRax/*}GeneRax/
  if [ -d ${grrepo} ] ; then
	grsrcvers=$(cd ${grrepo} && git log | head -n 1 | awk '{ print $2 }' 2> /dev/null && cd - > /dev/null)
	grsrcorig=$(cd ${grrepo} && git remote -v | grep fetch | awk '{ print $2 }' 2> /dev/null && cd - > /dev/null)
  fi
  if [ ! -z "${grsrcvers}" ] ; then
    GRsourcenote="using GeneRax software (version ${GRvtag}) compiled from source; code origin: ${grsrcorig}; code version ${grsrcvers}"
  else
    GRsourcenote="${GRheader} binaries found at '${pathgrbin}'"
  fi
fi

#generaxcommonopt="-r UndatedDTL --max-spr-radius 5 --strategy SPR" # now a pipeline default

if [[ "${chaintype}" == 'fullgenetree' ]] ; then
  # use the same species tree file for every gene family, with no collapsed populations
  spetree=${speciestree}_clade_defs.nwk
else
  # use a dedicated species tree file for each gene family, with population collapsed in accordance to the gene tree
  spetree='Stree.nwk'
  # this dictate that every family need to be run independently, thus loosing the benefit of built-in optimised load balance
fi
if [[ "${chaintype}" == 'fullgenetree' && "${GeneRaxalgo}" =~ 'global' ]] ; then
  # using the same species tree allows a single run of GeneRax, with built-in optimised load balance
  echo "detected 'global' keyword in reconciliation algorithm"
  echo "will run GeneRax on the whole pangenome with global parameter estimation"
  # generate a global family file i.e. job scheduling list and per-family parameter settings
  generaxfamfi=${alerec}/${reccol}_generax.families
  step1="create a family file i.e. parameter settings for the whole pangenome gene family set"
  python ${ptgscripts}/make_generax_family_file.py --alignments ${cdsalifastacodedir} --out ${generaxfamfi}
  checkexec "failed to ${step1}" "successfully ${step1/create/created}"
  step2="run GeneRax on all pangenome genes at once"
#  grlog=${grxlogs}/generax_global.log
  export ncpus=${ptgthreads}
  echo "${step2} (using GeneRax built-in optimised load balance on ${ncpus} cores)"
  ${ptgscripts}/generax_global_mpi.sh ${generaxfamfi}
  checkexec "failed to ${step2}" "successfully ${step2/run/ran}"
else  
  echo "will run GeneRax independently on each pangenome gene family, with family-specific parameter estimation"
  # generate a family file i.e. parameter settings for each gene family
  step1="create a family file i.e. parameter settings for each gene family"
  generaxfamfidir=${alerec}/${reccol}_generax_families
  mkdir -p ${generaxfamfidir}/
  gttorecdir=${coltreechains}/${collapsecond}/${replmethod}
  python ${ptgscripts}/make_generax_family_file.py --per-family --alignments ${gttorecdir} \
   --gene-trees ${gttorecdir} --out ${generaxfamfidir} --gftag '.generax.families'
  checkexec "failed to ${step1}" "successfully ${step1/create/created}"
  
  tasklist=${generaxfamfidir}_list
  if [ -z "${genefamlist}" ] ; then
    ${ptgscripts}/lsfullpath.py "${generaxfamfidir}/*.generax.families" > ${tasklist}
  else
    rm -f ${tasklist}
    for fam in $(cut -f1 ${genefamlist}) ; do
      ls ${generaxfamfidir}/${fam}*.generax.families 2> /dev/null
    done > ${tasklist} 
  fi
  
#  grlog=${grxlogs}/generax_perfam.log
  export ncpus=1
  step2="run GeneRax on each pangenome gene family in parallel"
  echo "${step2} (using GNU parallel on ${ptgthreads} cores, ${ncpus} thread(s) per process)"
  parallel -j ${ptgthreads} ${ptgscripts}/generax_perfam.sh :::: ${tasklist}
  checkexec "failed to ${step2}" "successfully ${step2/run/ran}"
		
fi

echo -e "${reccolid}\t${reccoldate}\t${GRsourcenote}\t${reccol}" > ${alerec}/reccol
echo -e "\n# Reconciliation collection details:"
cat ${alerec}/reccol