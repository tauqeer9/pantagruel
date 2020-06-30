#!/bin/bash

### verify and parse key variable definition

# generaxfamfi
echo "generaxfamfi:"
if [ -z "${generaxfamfi}" ] ; then
  generaxfamfi="${1}"
  if [ -z "${generaxfamfi}" ] ; then
    echo "missing mandatory argument: generax family file path (to pass either through env var \$generaxfamfi or as positional argument \$1); exit now"
	exit 1
  fi
  ls ${generaxfamfi}
  if [ ${?} != 0 ] ; then
    echo "ERROR: generax family file '${generaxfamfi}' is missing/empty ; exit now"
    exit 2
  fi
  nfrad1=$(basename ${generaxfamfi})
  nfext=${nfrad1##*.}
  nfrad2=${nfrad1%.*}
  echo ${nfrad2}
fi
# spetreedir
if [ ! -z "${spetreedir}" ] ; then
  echo "a folder was specified where to find the gene-family-specific species tree: ${spetreedir}"
else
  spetreedir=$(dirname ${generaxfamfi})
fi
# outrecdir
echo "outrecdir:"
if [ -z "${outrecdir}" ] ; then
  echo "ERROR: need to define variable outrecdir ; exit now"
  exit 2
else
  ls ${outrecdir} -d
  if [ ${?} != 0 ] ; then
    echo "directory '${outrecdir}' is missing ; create it now"
    mkdir -p ${outrecdir}/
    if [ ${?} != 0 ] ; then
      echo "could not create directory '${outrecdir}' ; exit now"
      exit 2
    fi
  fi
fi
# spetree
echo "spetree:"
if [ -z "${spetree}" ] ; then
  echo "ERROR: need to define variable spetree ; exit now"
  exit 2
else
  if [ -s ${spetree} ] ; then
    nfstree=${spetree}
  else
    echo "look for ${spetree} species tree file in folder ${spetreedir}/"
    ls ${spetreedir}/${nfrad2}*${spetree}*
    if [ ${?} != 0 ] ; then
      echo "ERROR: species tree file '${spetree}' is missing from folder ${spetreedir}/ ; exit now"
      exit 2
    else
      echo "found it!" 
      lnfstree=(`ls ${spetreedir}/${nfrad2}*${spetree}*`)
      nfstree=${lnfstree[0]}
    fi
  fi
  echo "will use nfstree=${nfstree}"
fi
# grbin
if [ -z "${grbin}" ] ; then
  grbin="generax"
fi
# generaxcommonopt
if [ -z "${generaxcommonopt}" ] ; then
  generaxcommonopt="-r UndatedDTL --max-spr-radius 5 --strategy SPR" # env var is a pipeline default
fi
generaxopt=" --per-family-rates"
# GeneRaxalgo
if [ ${GeneRaxalgo} == 'reconciliation-samples' ] ; then
  generaxopt="${generaxopt} --reconciliation-samples ${recsamplesize}"
else
  generaxopt="${generaxopt} --reconcile"
fi
# ncpus
if [ -z "${ncpus}" ] ; then
  ncpus=1
fi

### excute task

mkdir -p ${outrecdir}

if [ ${ncpus} -gt 1 ] ; then
  grxexe="mpirun -np ${ncpus} ${grbin}"
  # test which syntax to use
  ${grxexe} > /dev/null
  if [ ${?} != 0 ] ; then
    # Imperial HPC's querky refusal of mpirun
    grxexe="mpiexec ${grbin}"
  fi 
else
  grxexe="${grbin}"
fi

grxcmd="${grxexe} ${generaxcommonopt} -s ${nfstree} -f ${generaxfamfi} -p ${outrecdir} ${generaxopt}"
echo "# ${grxcmd}"
eval ${grxcmd}

if [ "${GeneRaxalgo}" == 'reconciliation-samples' ] ; then
  # clean up by deleting the highly redundant transfer list files
  for fam in $(grep '^- ' ${generaxfamfi} | cut -d' ' -f2) ; do
    rm ${outrecdir}/reconciliations/${fam}*_transfers.txt
  done
fi
