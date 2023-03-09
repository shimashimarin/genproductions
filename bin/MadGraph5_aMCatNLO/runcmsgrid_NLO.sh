#!/bin/bash

nevt=${1}
echo "%MSG-MG5 number of events requested = $nevt"

rnum=${2}
echo "%MSG-MG5 random seed used for the run = $rnum"

ncpu=${3}
echo "%MSG-MG5 number of cpus = $ncpu"

LHEWORKDIR=`pwd`

use_gridpack_env=true
if [ -n "$4" ]
  then
  use_gridpack_env=$4
fi

if [ "$use_gridpack_env" = true ]
  then
    if [ -n "$5" ]
    then
        scram_arch_version=${5}
    else
        scram_arch_version=SCRAM_ARCH_VERSION_REPLACE
    fi
    echo "%MSG-MG5 SCRAM_ARCH version = $scram_arch_version"
    
    if [ -n "$6" ]
    then
        cmssw_version=${6}
    else
        cmssw_version=CMSSW_VERSION_REPLACE
    fi
    echo "%MSG-MG5 CMSSW version = $cmssw_version"
    export VO_CMS_SW_DIR=/cvmfs/cms.cern.ch
    source $VO_CMS_SW_DIR/cmsset_default.sh
    export SCRAM_ARCH=${scram_arch_version}
    scramv1 project CMSSW ${cmssw_version}
    cd ${cmssw_version}/src
    eval `scramv1 runtime -sh`
fi

# [ runcmsgrid.sh ]: if there is process folder, will run locally; if not, will try ReadOnly mode
doReadOnly=0
if [ ! -d "process" ]; then
    echo "[ runcmsgrid.sh ] try to run in ReadOnly mode"
    doReadOnly=1
fi

if [ ! -z "${PYTHON27PATH}" ]; then export PYTHONPATH=${PYTHON27PATH}; fi
#make sure lhapdf points to local cmssw installation area
LHAPDFCONFIG=$(echo "$LHAPDF_DATA_PATH/../../bin/lhapdf-config")

# workaround for el8
LHAPDFLIBS=$($LHAPDFCONFIG --libdir)
LHAPDFPYTHONVER=$(find $LHAPDFLIBS -name "python*" -type d -exec basename {} \;)
LHAPDFPYTHONLIB=$(find $LHAPDFLIBS/$LHAPDFPYTHONVER/site-packages -name "*.egg" -type d -exec basename {} \;)
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LHAPDFLIBS

if [ ! -z "${LHAPDFPYTHONLIB}" ]; then
    export PYTHONPATH=$PYTHONPATH:$LHAPDFLIBS/$LHAPDFPYTHONVER/site-packages/$LHAPDFPYTHONLIB
else
    export PYTHONPATH=$PYTHONPATH:$LHAPDFLIBS/$LHAPDFPYTHONVER/site-packages
fi

if [ "$doReadOnly" -gt "0" ]; then
    # [ runcmsgrid.sh ] ReadOnly mode: create links to gridpack, madgraph
    WORKDIR="${LHEWORKDIR}/workdir"
    GRIDPACK="/eos/lyoeos.in2p3.fr/scratch/jxiao_dl/gp/untar"
    # MADGRAPH="/eos/lyoeos.in2p3.fr/scratch/jxiao_dl/mg5amcnlo"
    ${LHEWORKDIR}/mk_workdir.py -i $GRIDPACK -o $WORKDIR
    # cd $WORKDIR
    # ${LHEWORKDIR}/mk_workdir.py -i $MADGRAPH -o mgbasedir
    # cd mgbasedir
    # # link models to the MG5
    # rm -r models
    # ${LHEWORKDIR}/mk_workdir.py -i $GRIDPACK/models -o models
    cd $WORKDIR/process
    #[ runcmsgrid.sh ] ReadOnly mode: replace some linked files
    cat ./Cards/amcatnlo_configuration.txt >tmp_amcatnlo_configuration.txt
    unlink ./Cards/amcatnlo_configuration.txt
    mv tmp_amcatnlo_configuration.txt ./Cards/amcatnlo_configuration.txt
else
    WORKDIR="${LHEWORKDIR}"
    # only models folder is saved to gridpack, so the Madgraph5 is from external places
    chmod -R 777 $LHEWORKDIR/process # switch off ReadOnly mode
    cd $LHEWORKDIR/process
    
    echo "madspin=OFF" >runscript.dat
    echo "reweight=OFF" >>runscript.dat
    echo "done" >>runscript.dat

    echo "set nevents $nevt" >>runscript.dat
    echo "set iseed $rnum" >>runscript.dat

    #set job splitting for worker processes
    nevtjob=$(($nevt / $ncpu))
    if [ "$nevtjob" -lt "10" ]; then
        nevtjob=10
    fi

    echo "set nevt_job ${nevtjob}" >>runscript.dat
    echo "done" >>runscript.dat
fi

echo "lhapdf_py3 = $LHAPDFCONFIG" >> ./Cards/amcatnlo_configuration.txt
# echo "cluster_local_path = `${LHAPDFCONFIG} --datadir`" >> ./Cards/amcatnlo_configuration.txt

echo "run_mode = 2" >> ./Cards/amcatnlo_configuration.txt
echo "nb_core = $ncpu" >> ./Cards/amcatnlo_configuration.txt

domadspin=0
if [ -f ./Cards/tmp_madspin_card ]; then
    if [ "$doReadOnly" -gt "0" ]; then
        # [ runcmsgrid.sh ] MG5 will try to move madspin_card.dat to .madspin_card.dat
        # [ runcmsgrid.sh ] use tmp_madspin_card to avoid this, since this break the ReadOnly mode
        cat ./Cards/tmp_madspin_card > tmp_madspin_card2
        unlink ./Cards/tmp_madspin_card
        mv tmp_madspin_card2 ./Cards/tmp_madspin_card
        # set random seed for madspin
        sed -i "/set.*seed/d" ./Cards/tmp_madspin_card # delete existing lines contain set seed 
        echo "$(echo $(echo "set seed ${rnum}") | cat - ./Cards/tmp_madspin_card)" >./Cards/tmp_madspin_card
        # set ms_dir
        sed -i "s/^\s*set\s*ms_dir.*$/set ms_dir ..\/..\/process\/madspin/" ./Cards/tmp_madspin_card
        # import events.lhe
        sed -i "/import.*events/d" ./Cards/tmp_madspin_card # delete existing lines contain import events 
        echo "$(echo $(echo "import ./events.lhe") | cat - ./Cards/tmp_madspin_card)" >./Cards/tmp_madspin_card
        # [ runcmsgrid.sh ] set the permission of $WORKDIR/process to ReadOnly
        # [ runcmsgrid.sh ] or it will write decayed.lhe to the process/madspin
        # [ runcmsgrid.sh ] then the code will not consider it's rReadOnly
        chmod -R 555 $WORKDIR/process
        domadspin=1
    else
        #set random seed for madspin
        rnum2=$(($rnum + 1000000))
        echo "$(echo $(echo "set seed $rnum2") | cat - ./Cards/tmp_madspin_card)" >./Cards/tmp_madspin_card
        domadspin=1
    fi
fi

doreweighting=0
if [ -f ./Cards/reweight_card.dat ]; then
    doreweighting=1
fi

runname=cmsgrid

if [ "$doReadOnly" -gt "0" ]; then
    #[ runcmsgrid.sh ] ReadOnly mode: set run folder
    mkdir -p $WORKDIR/Events/${runname}
    cd $WORKDIR/Events/${runname}
fi

#generate events

#First check if normal operation with MG5_aMCatNLO events is planned
if [ ! -e $LHEWORKDIR/header_for_madspin.txt ]; then
  
    if [ "$doReadOnly" -gt "0" ]; then
        # [ runcmsgrid.sh ] ReadOnly mode: hide the madspin_card.dat when run ./bin/run.sh
        if [ -e $WORKDIR/process/Cards/madspin_card.dat ]; then
            mv $WORKDIR/process/Cards/madspin_card.dat $WORKDIR/process/Cards/.madspin_card.dat
        fi
        $WORKDIR/process/bin/run.sh $nevt $rnum
    else
        cat runscript.dat | ./bin/generate_events -ox -n $runname
    fi
    runlabel=$runname

    if [ "$doreweighting" -gt "0" ] ; then
        #when REWEIGHT=OFF is applied, mg5_aMC moves reweight_card.dat to .reweight_card.dat
        mv ./Cards/.reweight_card.dat ./Cards/reweight_card.dat
        rwgt_dir="$LHEWORKDIR/process/rwgt"
        export PYTHONPATH=$rwgt_dir:$PYTHONPATH
        echo "0" | ./bin/aMCatNLO --debug reweight $runname
    fi
    if [ "$doReadOnly" -gt "0" ]; then
        gzip -d $WORKDIR/Events/${runlabel}/events.lhe
    else
        gzip -d $LHEWORKDIR/process/Events/${runlabel}/events.lhe
    fi

    if [ "$domadspin" -gt "0" ] ; then
        if [ ! "$doReadOnly" -gt "0" ]; then
            mv $LHEWORKDIR/process/Events/${runlabel}/events.lhe events.lhe
        fi
        # extract header as overwritten by madspin
        if grep -R "<initrwgt>" events.lhe; then
            sed -n '/<initrwgt>/,/<\/initrwgt>/p' events.lhe >initrwgt.txt
        fi
        #when MADSPIN=OFF is applied, mg5_aMC moves madspin_card.dat to .madspin_card.dat
        if [ "$doReadOnly" -gt "0" ]; then
            # [ runcmsgrid.sh ] ReadOnly mode: run MadSpin
            ../../mgbasedir/MadSpin/madspin $WORKDIR/process/Cards/tmp_madspin_card
        else
            echo "import events.lhe" >madspinrun.dat
            cat ./Cards/tmp_madspin_card >>madspinrun.dat
            $LHEWORKDIR/mgbasedir/MadSpin/madspin madspinrun.dat
        fi
        # add header back
        gzip -d events_decayed.lhe.gz
        if [ -e initrwgt.txt ]; then
            sed -i "/<\/header>/ {
             h
             r initrwgt.txt
             g
             N
        }" events_decayed.lhe
            rm initrwgt.txt
        fi
        if [ "$doReadOnly" -gt "0" ]; then
            mv $WORKDIR/Events/${runlabel}/events_decayed.lhe $WORKDIR/Events/${runlabel}/events.lhe
        else
            runlabel=${runname}_decayed_1
            mkdir -p ./Events/${runlabel}
            mv $LHEWORKDIR/process/events_decayed.lhe $LHEWORKDIR/process/Events/${runlabel}/events.lhe
        fi
    fi
    pdfsets="PDF_SETS_REPLACE"
    scalevars="--mur=1,2,0.5 --muf=1,2,0.5 --together=muf,mur --dyn=-1"

    if [ "$doReadOnly" -gt "0" ]; then
        # [ runcmsgrid.sh ] ReadOnly mode: standalonely run systematics.py to add PDF/Scale weights
        python3 $WORKDIR/process/bin/internal/systematics.py $WORKDIR/Events/${runlabel}/events.lhe --start_id=1001 --pdf=$pdfsets $scalevars --lhapdf_config=$LHAPDFCONFIG
        cp $WORKDIR/Events/${runlabel}/events.lhe $LHEWORKDIR/${runname}_final.lhe
    else
        echo "systematics $runlabel --start_id=1001 --pdf=$pdfsets $scalevars" | ./bin/aMCatNLO
        cp $LHEWORKDIR/process/Events/${runlabel}/events.lhe $LHEWORKDIR/${runname}_final.lhe
    fi
#else handle external tarball
else
    cd $LHEWORKDIR/external_tarball

    ./runcmsgrid.sh $nevtjob $rnum $ncpu

#splice blocks needed for MadSpin into LHE file
    sed -i "/<init>/ {
         h
         r ../header_for_madspin.txt
         g
         N
     }" cmsgrid_final.lhe

#check if lhe file has reweighting blocks - temporarily save those, because MadSpin later overrides the entire header
    if grep -R "<initrwgt>" cmsgrid_final.lhe; then
        sed -n '/<initrwgt>/,/<\/initrwgt>/p' cmsgrid_final.lhe > ../initrwgt.txt
    fi

    mv cmsgrid_final.lhe ../cmsgrid_predecay.lhe
    cd $LHEWORKDIR
    rm -r external_tarball
    echo "import $LHEWORKDIR/cmsgrid_predecay.lhe" > madspinrun.dat
    echo "set ms_dir $LHEWORKDIR/process/madspingrid" >> madspinrun.dat
    echo "launch" >> madspinrun.dat
    $LHEWORKDIR/mgbasedir/MadSpin/madspin madspinrun.dat
    rm madspinrun.dat
    rm cmsgrid_predecay.lhe.gz
    mv cmsgrid_predecay_decayed.lhe.gz cmsgrid_final.lhe.gz
    gzip -d cmsgrid_final.lhe.gz

    if [ -e initrwgt.txt ];then
	sed -i "/<\/header>/ {
             h
             r initrwgt.txt
             g
             N
        }" cmsgrid_final.lhe
        rm initrwgt.txt
    fi
    
fi

cd $LHEWORKDIR
sed -i -e '/<mgrwgt/,/mgrwgt>/d' ${runname}_final.lhe 

# check lhe output  
mv ${LHEWORKDIR}/${runname}_final.lhe ${LHEWORKDIR}/test.lhe 
echo -e "\nRun xml check" 
xmllint --stream --noout ${LHEWORKDIR}/test.lhe ; test $? -eq 0 || exit 1 
echo "Number of weights that are NaN:" 
grep  NaN  ${LHEWORKDIR}/test.lhe | grep "</wgt>" | wc -l ; test $? -eq 0 || exit 1 
echo -e "All checks passed \n" 

# copy output and print directory 
mv ${LHEWORKDIR}/test.lhe ${LHEWORKDIR}/${runname}_final.lhe
ls -l

# [ runcmsgrid.sh ] Switch OFF the $WORKDIR ReadOnly
chmod -R 777 $WORKDIR

# exit 
exit 0
