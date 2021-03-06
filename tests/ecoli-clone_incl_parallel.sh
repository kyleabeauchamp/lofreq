#!/bin/bash

# Test that we get the number of expected SNVs on a clonal data-set
# and also check whether running it in parallel (single genome!) works
# and produces same results

source lib.sh || exit 1


basedir=data/ecoli-clone/
bam=$basedir/clone/EAS20_8.bwamem_pe.viterbi.mdups.realn.recal.bam
reffa=$basedir/ref/Ecoli_K12_MG1655_NC_000913.fa
#truesnv=$basedir/denv2-pseudoclonal_true-snp.vcf

outdir=$(mktemp -d -t $(basename $0).XXXXXX)
outvcf_p=$outdir/$(basename $bam .bam)_parallel.vcf.gz
outvcf_s=$outdir/$(basename $bam .bam)_single.vcf.gz
log=$outdir/log.txt

KEEP_TMP=0

cmd="$LOFREQ call-parallel --pp-threads $threads -f $reffa -o $outvcf_p $bam"
#echodebug "cmd=$cmd"
if ! eval $cmd >> $log 2>&1; then
    echoerror "The following command failed (see $log for more): $cmd"
    exit 1
fi


#MAX_SNVS=20
MAX_SNVS=50


# run in parallel (should work in single chromosome) 
#
nsnvs=$(grep -c '^[^#]' $outvcf_p)
if [ $nsnvs -ge $MAX_SNVS ]; then
    echoerror "Expected less then $MAX_SNVS on this clonal dataset but got $nsnvs (see $outdir)"
    exit 1
else
    echook "Got $nsnvs SNVs for this clonal dataset which is okay (below limit of $MAX_SNVS)"
fi



# run single and compare results
# 
cmd="$LOFREQ call -f $reffa -o $outvcf_s $bam"
#echodebug "cmd=$cmd"
if ! eval $cmd >> $log 2>&1; then
    echoerror "The following command failed (see $log for more): $cmd"
    exit 1
fi


nus=$($LOFREQ vcfset -a complement -1 $outvcf_s -2 $outvcf_p --count-only)
nup=$($LOFREQ vcfset -a complement -2 $outvcf_s -1 $outvcf_p --count-only)
# allowing one border line difference
if [ $nus -gt 1 ] || [ $nup -gt 1 ]; then
    echoerror "Observed differences between parallel ($nup unique vars) and single ($nus unique vars) results. Check $outvcf_p and $outvcf_s"
    exit 1
fi                                    


if [ $KEEP_TMP -eq 1 ]; then
    echowarn "Not deleting tmp dir $outdir"
else 
    rm $outdir/*
    rmdir $outdir
fi
