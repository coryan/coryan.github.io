#!/bin/bash

# First make sure we are in a directory where we can find the
# microbenchmark ...

if [ ! -x ./jb/itch5/bm_order_book ]; then
    echo "This program should be run in a directory where you have"
    echo "built jaybeams.  Check github.com/coryan/jabeams for"
    echo "installation instructions"
    exit 1
fi

if [ -r tools/benchmark_common.sh ]; then
    . ./tools/benchmark_common.sh
elif [ -r ../tools/benchmark_common.sh ]; then
    . ../tools/benchmark_common.sh
else
    echo "Cannot locate common benchmark shell functions (benchmark_common.sh)"
    echo "Is this build location separate from the source?"
    exit 1
fi

# A function to start N jobs that keep the cores busy ...
start_load() {
    local NUMCPU=$(grep $'^processor\t*:' /proc/cpuinfo |wc -l)
    local cpu
    for cpu in `seq 1 ${NUMCPU?}`; do
        dd if=/dev/zero of=/dev/null >/dev/null </dev/null 2>&1 &
    done
}

# Stop the jobs started in start_load()
stop_load() {
    kill $(jobs -rp) >/dev/null 2>/dev/null 
    wait $(jobs -rp) >/dev/null 2>/dev/null 
}

# A function to run the bm_order_book microbenchmark N times
execute_runs() {
    local count=$1
    shift
    local tname=$1
    shift
    local i
    for i in `seq 1 ${count?}`; do
        # ... execute a harmless sudo command in each iteration so we
        # can keep the sudo token and run this without human attention
        # after it starts ...
        sudo uptime >/dev/null 2>&1
        # ... run the benchmark as requested ...
        ./jb/itch5/bm_order_book \
            --microbenchmark.verbose=true \
            --microbenchmark.iterations=5000 \
            --microbenchmark.test-case=map:buy \
            --microbenchmark.prefix=run_${i},${tname?}, \
            $* >$TMPOUT 2>$TMPERR && \
            (cat $TMPERR | log $LOG) && \
            (cat $TMPOUT >>$LOG)
    done
}

execute_scheduling_scenarios() {
    local loaded=$1
    shift
    local seeded=$1
    shift
    # ... we need to test different schedulers for the microbenchmark ...
    local rtsched
    for rtsched in default rt:default rt:unlimited; do
        local schedarg=""
        [ "x${rtsched?}" != "xdefault" ] || \
            schedarg="--microbenchmark.reconfigure-thread=false"
        local sys_sched_file="/proc/sys/kernel/sched_rt_runtime_us"
        if [ "x${rtsched}" = "xrt:unlimited" ]; then
            echo -1 | sudo tee ${sys_sched_file?} >/dev/null
        else
            echo 950000 | sudo tee ${sys_sched_file?} >/dev/null
        fi
        # ... test with multiple CPU frequency governors ...
        local GOVS="ondemand performance"
        # ... the virtual machines we use (Google Compute Engine) do
        # not have cpu frequency governors, so run a simpler test for
        # them ...
        [ "x${mtype?}" != "xvm" ] || GOVS="nogovernor"
        local governor
        for governor in ondemand performance; do
            tname="${mtype?},${loaded?},${seeded?},${rtsched?},${governor?}"
            [ "x${governor}" = "xnogovernor" ] || \
                sudo cpupower frequency-set -g $governor | log $LOG
            execute_runs 4 ${tname?} ${schedarg} $*
        done # rtsched
    done # seeded
}

main() {
    local mtype=$1
    shift
    if [ "x${mtype?}" = "x" ]; then
        # ... this is just a label to remind us that the tests were
        # executed on a workstation ...
        mtype=wkst
    fi

    benchmark_startup
    local load
    for load in unloaded loaded; do
        [ "x${load?}" != "xloaded" ] || start_load
        local seeded
        for seeded in urandom fixed; do
            local seedarg=""
            [ "x${seeded?}" != "xfixed" ] || seedarg="--seed=3239495522"
            execute_scheduling_scenarios ${load?} ${seeded?} ${seedarg?}
        done
        [ "x${load?}" != "xloaded" ] || stop_load
    done
    benchmark_teardown
    # ... print the environment and configuration at the end because it is
    # very slow ...
    echo "Capturing system configuration... patience..."
    print_environment ./jb/itch5/bm_order_book | log $LOG
}

main $*

exit 0
