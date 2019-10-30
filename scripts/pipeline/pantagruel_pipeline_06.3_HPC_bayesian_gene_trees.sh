#!/bin/bash

#########################################################
## PANTAGRUEL:                                         ##
##             a pipeline for                          ##
##             phylogenetic reconciliation             ##
##             of a bacterial pangenome                ##
#########################################################

# Copyright: Florent Lassalle (f.lassalle@imperial.ac.uk), 15 Jan 2019

if [ -z "$1" ] ; then
  echo "missing mandatory parameter: pantagruel config file"
  echo "Usage: $0 ptg_env_file [hpc_type:{PBS(default)|LSF}]"
  exit 1
fi
envsourcescript="$1"
if [ -z "$2" ] ; then 
  hpctype='PBS'
else
  hpctype="$2"
fi
envsourcescript="$1"
source ${envsourcescript}

############################
## 06.3 Bayesian gene trees
############################

## run mrbayes on collapsed alignments
export nexusaln4chains=${colalinexuscodedir}/${collapsecond}/collapsed_alns
export mboutputdir=${bayesgenetrees}/${collapsecond}
mkdir -p ${mboutputdir}
nchains=4
nruns=2
ncpus=$(( ${nchains} * ${nruns} ))
mem=16 # in GB
wth=24
tasklist=${nexusaln4chains}_ali_list
rm -f ${tasklist}
${ptgscripts}/lsfullpath.py "${nexusaln4chains}/*nex" > ${tasklist}
dtag=$(date +"%Y-%m-%d-%H-%M-%S")
append=''

# determine the set of numbered gene family prefixes to make separate folders
# and breakdown the load of files per folder
awk -F'/' '{print $NF}' ${mbtasklist} | grep -o "${famprefix}C[0-9]\{${ndiggrpfam}\}" | sort -u > ${nexusaln4chains}_ali_numprefixes
for pref in  `cat ${nexusaln4chains}_ali_numprefixes` ; do
  mkdir -p ${mboutputdir}/${pref}/
done

if [ "${resumetask}" == 'true' ] ; then
  #~ # following lines are for resuming after a stop in batch computing, or to collect those jobs that crashed (and may need to be re-ran with more mem/time allowance)
  for nfaln in $(cat $tasklist) ; do
   bnaln=$(basename $nfaln)
   bncontre=${bnaln/nex/mb.con.tre}
   pref=$(echo ${bncontre} | grep -o "${famprefix}C[0-9]\{${ndiggrpfam}\}")
   if [ ! -e ${mboutputdir}/${pref}/${bncontre} ] ; then
    echo ${nfaln}
   fi
  done > ${tasklist}_resumetask_${dtag}
  tasklist=${tasklist}_resumetask_${dtag}
  export mbmcmcopt='append=yes'
else
  export mbmcmcopt=''
fi
export mbmcmcpopt='Nruns=${nruns} Ngen=2000000 Nchains=${nchains}'
qsubvars="tasklist=${tasklist}, outputdir=${mboutputdir}"
if [ ! -z "${mbbin}" ] ; then
  qsubvars="${qsubvars}, mbbin=${mbbin}"
fi

Njob=`wc -l ${tasklist} | cut -f1 -d' '`
chunksize=1000
jobranges=($(${ptgscripts}/get_jobranges.py $chunksize $Njob))
for jobrange in ${jobranges[@]} ; do
 dlogs=${ptglogs}/mrbayes/${chaintype}_mrbayes_trees_${collapsecond}_${dtag}_${jobrange}
 mkdir -p ${dlogs}/
 
 case "$hpctype" in
    'PBS') 
      subcmd="qsub -J ${jobrange} -N mb_panterodb -l select=1:ncpus=${ncpus}:mem=${mem}gb -l walltime=${wth}:00:00 \
	  -o ${dlogs} -v \"$qsubvars, mbmcmcopt='${mbmcmcopt}', mbmcmcpopt='${mbmcmcpopt}'\" ${ptgscripts}/mrbayes_array_PBS.qsub"
	  ;;
	'LSF')
	  if [ ${wth} -le 12 ] ; then
	    bqueue='normal'
	  elif [ ${wth} -le 48 ] ; then
	    bqueue='long'
	  else
	    bqueue='basement'
	  fi
	  memmb=$((${mem} * 1024)) 
	  subcmd="bsub -J \"mb_panterodb[$jobrange]\" -q ${bqueue} \
	  -R \"select[mem>${memmb}] rusage[mem=${memmb}] span[ptile=${ncpus}]\" -n${ncpus} -M${memmb} \
	  -o ${dlogs}/mrbayes.%J.%I.o -e ${dlogs}/mrbayes.%J.%I.e -env \"$qsubvars, mbmcmcopt, mbmcmcpopt\" \
	  ${ptgscripts}/mrbayes_array_LSF.bsub"
	  ;;
	*)
	  echo "Error: high-performance computer system '$hpctype' is not supported; exit now"
	  exit 1;;
  esac
  echo "${subcmd}"
  eval "${subcmd}"
done
