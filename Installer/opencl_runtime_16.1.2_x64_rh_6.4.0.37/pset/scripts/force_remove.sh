#!/bin/bash

# Copyright (c) 2014-2016 Intel Corporation. All rights reserved.
# This script configures Intel(R) Software Development Products.

declare IS_NONRPM=
declare NONRPM_DB_PREFIX="$HOME/intel"
[ -w /dev ] && NONRPM_DB_PREFIX="/opt/intel"
declare INTEL_SDP_PRODUCTS_DB="$NONRPM_DB_PREFIX/intel_sdp_products.db"
[ -f "$INTEL_SDP_PRODUCTS_DB" ] && IS_NONRPM=1

declare IS_RPM=1
rpm &> /dev/null
[ $? -eq 127 ] && IS_RPM=
rpm -q rpm &> /dev/null
[ $? -ne 0 ] && IS_RPM=

declare -a nonrpm_db
[ "$IS_NONRPM" = "1" ] && nonrpm_db=$(cat "$INTEL_SDP_PRODUCTS_DB" 2>/dev/null)



declare RS=""
declare -a RA
declare rpm_count=0
declare nonrpm_count=0


function NONRPM_DB_ENTRY_GET_RPMNAME() {
    NONRPM_DB_ENTRY_GET_FIELD "$1" 2
}
function NONRPM_DB_ENTRY_GET_RPMFILE() {
    NONRPM_DB_ENTRY_GET_FIELD "$1" 3
}
function NONRPM_DB_ENTRY_GET_FIELD() {
    RS=$(echo "$1" | cut -d':' -f"$2")
}
function NONRPM_DB_ENTRY_GET_INSTALLDIR() {
    NONRPM_DB_ENTRY_GET_FIELD "$1" 4
}
function NONRPM_DB_ENTRY_GET_LOGFILE() {
    NONRPM_DB_ENTRY_GET_FIELD "$1" 5
}

function NONRPM_UNINSTALL_PACKAGE()
{
    local entry="$1"

    NONRPM_DB_ENTRY_GET_LOGFILE "$entry"
    local log_file=$RS
    if [ ! -f "$log_file" ]; then
	    echo "Uninstallation cannot continue for this component: Missing \"$log_file\"."
	    return 1
    fi

    NONRPM_DB_ENTRY_GET_INSTALLDIR "$entry"
    local install_dir=$RS
    if [ ! -d "$install_dir" ]; then
	   echo "Uninstallation cannot continue for this component: Missing \"$install_dir\" directory."
	   return 1
    fi

    local script_dir="$install_dir/.scripts"
    NONRPM_DB_ENTRY_GET_RPMFILE "$entry"
    local rpm_name=$RS

    if [ -f "$script_dir/PREUN.$rpm_name" ]; then
        env RPM_INSTALL_PREFIX="$install_dir" /bin/bash "$script_dir/PREUN.$rpm_name"
    fi

    tac "$log_file" | \
    while read line; do
        if [ -h "$line" ] || [ -f "$line" ]; then
            rm -f "$line"
            [ $? -ne 0 ] && echo "cannot delete file: $line"
        elif [ -d "$line" ]; then
            rmdir --ignore-fail-on-non-empty "$line"
            [ $? -ne 0 ] && echo "cannot delete directory: $line"
        fi	
    done

    if [ -f "$script_dir/POSTUN.$rpm_name" ]; then
        env RPM_INSTALL_PREFIX="$install_dir" /bin/bash "$script_dir/POSTUN.$rpm_name"
    fi

    local script
    for script in PREIN POSTIN PREUN POSTUN SUMMARY; do
        rm -f "$script_dir/$script.$rpm_name"
    done

    [ -d "$script_dir" ] && rmdir --ignore-fail-on-non-empty  "$script_dir"
    [ -d "$install_dir" ] && rmdir --ignore-fail-on-non-empty "$install_dir"
    rm -f "$log_file"

    cp -p "$INTEL_SDP_PRODUCTS_DB" "$INTEL_SDP_PRODUCTS_DB~"
    grep -F -v -x "$entry" "$INTEL_SDP_PRODUCTS_DB~" > "$INTEL_SDP_PRODUCTS_DB"
    chmod --reference="$INTEL_SDP_PRODUCTS_DB~" "$INTEL_SDP_PRODUCTS_DB"
    rm -f "$INTEL_SDP_PRODUCTS_DB~" &>/dev/null
}



FORCE_REMOVE()
{
    local mc="$1/../mediaconfig.xml"
    local file_input=$(cat "$mc" | grep "<NONRPMProductCode>" | sed "s/\s*<NONRPMProductCode>//" | sed "s/<\/NONRPMProductCode>\s*//")
    local entry

    for rpmfile in $file_input; do
        if [ -n "$IS_RPM" ]; then
            rpm -e --nodeps "${rpmfile%%.rpm}"
            [ $? -eq 0 ] && rpm_count=$(( rpm_count + 1 ))
        fi
        
        for entry in $nonrpm_db; do
            NONRPM_DB_ENTRY_GET_RPMFILE "$entry"
            if [ "$rpmfile" == "$RS" ]; then
                NONRPM_UNINSTALL_PACKAGE $entry
                nonrpm_count=$(( nonrpm_count + 1 ))
            fi
        done
    done
}


thisexec=`basename "$0"`
thisdir=`dirname "$0"`

is_sourced=$(echo "$0" | grep "force_remove.sh")
if [ -z "$is_sourced" ]; then
    echo "Script is running sourced."
    echo "ERROR: This script uninstall product and should be called directly. Exiting..."
    exit 0
fi

if echo "$thisdir" | grep -q -s ^/ || echo "$thisdir" | grep -q -s ^~ ; then
   fullpath="$thisdir"
else
   runningdir=`pwd`
   fullpath="$runningdir/$thisdir"
fi

FORCE_REMOVE "$fullpath"
echo "RPM packages removed: $rpm_count"
echo "non-RPM packages removed: $nonrpm_count"

exit 0
