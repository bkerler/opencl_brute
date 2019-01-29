#!/bin/sh

# Copyright (c) 2006-2016 Intel Corporation. All rights reserved.
# This script configures Intel(R) Software Development Products.
EXIT_CODE_SUCCESS=0
EXIT_CODE_GUI_RUN_ERROR=1
EXIT_CODE_ERROR=2
EXIT_CODE_CANCEL=4

PRODUCT_ID=""

# 0 - ok
# 1 - nok
can_escalate_privileges()
{
    # by default (e.g. on Linux) user can do so
    local result=0
    if [ "$(uname)" = "FreeBSD" ]; then
        if ! groups $USER | grep wheel 2>&1 1>/dev/null; then
            result=1
        fi
    fi
    return $result
}

# 0 - ok
# 1 - nok
is_sudo_available()
{
    local result=1
    which sudo 2>&1 1>/dev/null
    [ $? -eq 0 ] && result=0
    return $result
}


check_cpu_model() {
    if [ "$(uname)" = "Darwin" ]; then
        CPU_FAMILY=$(echo $(sysctl -a | grep machdep.cpu.family |head -1|cut -d: -f2))
        CPU_MODEL=$(echo $(sysctl -a | grep machdep.cpu.model |head -1|cut -d: -f2))
    else
        CPU_FAMILY=$(echo $(grep family /proc/cpuinfo |head -1|cut -d: -f2))
        CPU_MODEL=$(echo $(grep model /proc/cpuinfo |head -1|cut -d: -f2))
    fi

    MIN_FAMILY=6
    MIN_MODEL=14

    if [ $CPU_FAMILY -lt $MIN_FAMILY ]; then
        echo "CPU is not supported."
        exit $EXIT_CODE_CANCEL
    elif [ $CPU_FAMILY -eq $MIN_FAMILY ] && [ $CPU_MODEL -lt $MIN_MODEL ]; then
        echo "CPU is not supported."
        exit $EXIT_CODE_CANCEL
    fi
}

prepare_pset_binary()
{
    pset_config_folder="$fullpath/pset"
    pset_engine_folder="$fullpath/pset/$my_arch"
    if [ "$(uname)" = "Darwin" ]; then
        pset_config_folder="`cd "$fullpath/../Resources/pset";pwd;cd - > /dev/null 2>/dev/null`"
        pset_engine_folder="$fullpath/../MacOS"
    elif [ "$pset_mode" = "uninstall" ]; then
        pset_config_folder="$fullpath/uninstall"
        pset_engine_folder="$fullpath/uninstall/$my_arch"
    fi
    pset_engine_binary="$pset_engine_folder/install_gui"
    pset_engine_cli_binary="$pset_engine_folder/install"

    # check the platform support
    if [ ! -r "$fullpath" ] || [ ! -x "$fullpath" ]; then
        echo "The installation script is launched from the directory which does not have read/execute access permissions."
        echo "Please copy the package to other location which is accessible by $USER user";
        echo 
        echo "Quitting!"
        exit $EXIT_CODE_CANCEL
    fi;
    if [ ! -f "$pset_engine_binary" ] && [ ! -f "$pset_engine_cli_binary" ]; then
        if [ ! -d "$pset_engine_folder" ]; then
            echo "The IA-32 architecture host installation is no longer supported."
            echo "The product cannot be installed on this system."
            echo "Please refer to product documentation for more information."
            echo ""
            echo "Quitting!"
            exit $EXIT_CODE_CANCEL
        fi
        if [ ! -x "$pset_engine_folder" ]; then
            if [ "yes" = "$skip_gui_install" ]; then
                echo "Can not execute $pset_engine_cli_binary: permission denied."
            else
                echo "Can not execute $pset_engine_binary: permission denied."
            fi
            echo "Please check the package was unpacked with proper permissions."
            echo ""
            echo "Quitting!"
            exit $EXIT_CODE_CANCEL
        fi

        echo "The IA-32 architecture host installation is no longer supported."
        echo "The product cannot be installed on this system."
        echo "Please refer to product documentation for more information."
        echo ""
        echo "Quitting!"
        exit $EXIT_CODE_CANCEL
    fi

    if [ ! -x "$pset_engine_binary" ]; then
        skip_gui_install=yes
        if [ ! -x "$pset_engine_cli_binary" ]; then
            echo "Can not execute $pset_engine_binary: permission denied."
            echo "Please check the package was unpacked with proper permissions."
            echo ""
            echo "Quitting!"
            exit $EXIT_CODE_CANCEL
        fi
    fi

    if [ -z "${libz_exist}" ]; then
        libz_path="$pset_engine_folder/libz"
    fi

    libqt_path="$pset_engine_folder/qt"

    [ "$(uname)" != "Darwin" ] && LD_LIBRARY_PATH="$fullpath/pset/$my_arch:$libqt_path:$libz_path:$LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH
}

parse_cmd_parameters()
{
    while [ $# -gt 0 ] ; do
    case "$1" in
    --silent|-s)
        silent_mode="yes"
        skip_uid_check="yes"
        ;;
    --help|-h|--version|-v)
        # show help message
        skip_uid_check="yes"
        skip_cd_eject="yes"
        skip_selinux_check="yes"
        minimal_launch="yes"
        params="$params $1"
        break
        ;;
    --user-mode|--download-list)
        # run installation under current user privileges
        skip_uid_check="yes"
        ;;
    --ignore-cpu)
        # skip cpu checking
        skip_cpu_check="yes"
        ;;
    --cli-mode)
        # don't start GUI installer
        skip_gui_install="yes"
        cli_mode_params="--cli-mode"
        ;;
    --gui-mode)
        # Start GUI installer even if default is CLI
        skip_gui_install=no
        ;;
    --check_only)
        # Just perform basic checks without launching installer
        check_only="yes"
        ;;
    *)
    esac
    case "$1" in
    --tmp-dir|-t)
        if [ -z "$2" ]; then
            echo "Error: Please provide temporary folder."
            exit $EXIT_CODE_CANCEL
        fi
        user_tmp="$2"
        shift
        ;;
    --download-dir|-D)
        dir=$2
        if [ -z "$dir" ]; then
            echo "Error: Please provide download temporal folder."
            exit $EXIT_CODE_CANCEL
        fi
        if echo $dir | grep -q -s ^/ || echo $dir | grep -q -s ^~ ; then
            # absolute path
            download_tmp="$dir"
        else
            # relative path
            download_tmp="$runningdir/$dir"
        fi

        if [ ! -d "$download_tmp" ]; then
            echo "Error: $download_tmp doesn't look like a proper folder."
            echo "Please make sure that this folder exists and run installation again."
            exit $EXIT_CODE_CANCEL
        fi

        shift
        ;;
    *)
        if test "${1#-}" != "$1"; then
            params="$params $1"
        else
            params="$params '$1'"
        fi        
    esac
    if [ "$#" -gt "0" ]; then
        shift
    fi
    done
}

check_runningdir()
{
    if [ -n "$(echo "$fullpath" | egrep -e ':' -e '~' -e '&' -e '%' -e '#' -e '@' -e '\[' -e '\]' -e '\$' -e '=' -e '\)' -e '\(' -e '\*')" ] ; then
        echo "Error: Incorrect path to setup script. Setup can not be started"
        echo "if the path contains ':, ~, @, #, %, &, [, ], $, =, ), (, *' symbols."
        echo ""
        echo "Quitting!"
        exit $EXIT_CODE_CANCEL
    fi
}

get_strings()
{
    strings_file="$user_tmp/intel.pset.strings.$USER.${HOSTNAME}"
    if [ -f "$pset_engine_cli_binary" ]; then
        "$pset_engine_cli_binary" --tmp_dir "$user_tmp" --TEMP_FOLDER="$temp_folder" --log-disable --__get_string__=$strings_file $params
    else
        "$pset_engine_binary" --tmp_dir "$user_tmp" --TEMP_FOLDER="$temp_folder" --log-disable --__get_string__=$strings_file $params 2>/dev/null
    fi
    exit_code=$?
    if [ -f $strings_file ] ; then
        . $strings_file
        rm $strings_file >/dev/null 2>&1
    else
        exit $exit_code;
    fi
}

privileges_ask_root()
{
    echo "$LI_bash_log_as_root"
    rm -rf $temp_folder >/dev/null 2>&1
    sh -c "(exec su - root -c \"sh \\\"$fullpath/$thisexec\\\" $cli_mode_params $params || true\")"
    if [ "$?" = "0" ]; then
        exit $EXIT_CODE_SUCCESS
    else 
        echo -n "$LI_bash_log_as_root_failed"
        read usr_choice >/dev/null 2>&1
        if [ "$usr_choice" = "y" ] || [ -z "$usr_choice" ]; then 
            REPEAT_LOOP=1
        else
            echo "$LI_bash_quit"
            exit $EXIT_CODE_SUCCESS
        fi    
    fi
}

privileges_ask_sudo()
{
    echo "$LI_bash_log_as_sudo"
    rm -rf $temp_folder >/dev/null 2>&1
    sh -c "(sudo su - root -c \"sh \\\"$fullpath/$thisexec\\\" $cli_mode_params $params || true\")"
    if [ "$?" = $EXIT_CODE_SUCCESS ]; then
        exit $EXIT_CODE_SUCCESS
    else
        echo -n "$LI_bash_log_as_sudo_failed"
        read usr_choice >/dev/null 2>&1
        if [ "$usr_choice" = "y" ] || [ -z "$usr_choice" ]; then 
            REPEAT_LOOP=1
        else
            echo "$LI_bash_quit"
            exit $EXIT_CODE_SUCCESS
        fi    
    fi
}

privileges_ask_user()
{
    echo "$LI_bash_log_as_user"
    REPEAT_LOOP=0
}

generate_n_display_dialog()
{
    root_nonroot_help="$LI_bash_log_root_nonroot_help_header"
    local idx=0
    echo "$LI_bash_root_nonroot_header"
    echo ""
    if [ $PRIVILEGE_MODE_ROOT -eq 1 ]; then
        idx=$((idx + 1))
        echo "${idx}. $LI_bash_run_as_root"
        root_nonroot_help="$root_nonroot_help \

-- $LI_bash_option ${idx} -- \
$LI_bash_log_root_nonroot_help_option_root"
    fi
    if [ $PRIVILEGE_MODE_SUDO -eq 1 ]; then
        idx=$((idx + 1))
        echo "${idx}. $LI_bash_run_as_sudo"
        root_nonroot_help="$root_nonroot_help \

-- $LI_bash_option ${idx} -- \
$LI_bash_log_root_nonroot_help_option_sudo"
    fi
    if [ $PRIVILEGE_MODE_USER -eq 1 ]; then
        idx=$((idx + 1))
        echo "${idx}. $LI_bash_run_as_user"
        root_nonroot_help="$root_nonroot_help \

-- $LI_bash_option ${idx} -- \
$LI_bash_log_root_nonroot_help_option_user"
    fi
    root_nonroot_help="$root_nonroot_help \

$LI_bash_log_root_nonroot_help_footer"

    echo "$LI_bash_root_nonroot_footer"
    echo " "
    echo -n "$LI_bash_root_nonroot_question"
}

cli_root_nonroot_dialog()
{
    REPEAT_LOOP=1

    PRIVILEGE_MODE_ROOT=1
    PRIVILEGE_MODE_SUDO=1
    PRIVILEGE_MODE_USER=1
    [ "$pset_mode" = "uninstall" ] && PRIVILEGE_MODE_USER=0
    ! is_sudo_available && PRIVILEGE_MODE_SUDO=0

    while [ "$REPEAT_LOOP" = 1 ]; do
        generate_n_display_dialog
        read  usr_choice >/dev/null 2>&1
        if [ -z "$usr_choice" ]; then
            usr_choice=1
        fi
        case $usr_choice in
        1 )
            privileges_ask_root
            ;;
        2 )
            if [ $PRIVILEGE_MODE_SUDO -eq 1 ]; then
                privileges_ask_sudo
            elif [ $PRIVILEGE_MODE_USER -eq 1 ]; then
                privileges_ask_user
            fi
            ;;
        3 )
            if [ $PRIVILEGE_MODE_USER -eq 1 ] && [ $PRIVILEGE_MODE_SUDO -eq 1 ]; then
                privileges_ask_user
            fi
            ;;
        h )
            echo "$root_nonroot_help"
            echo -n "$LI_to_continue_question"
            read  dummy >/dev/null 2>&1
            ;;
        q )
            echo "$LI_bash_log_quit"
            rm -rf $temp_dir >/dev/null 2>&1
            exit 4
            ;;

        * ) echo "$LI_bash_log_invalid_choice"
            REPEAT_LOOP=1 
            ;;
        esac
    done
}

# script start
thisexec=`basename "$0"`
thisdir=`dirname "$0"`
[ -z "$HOSTNAME" ] && HOSTNAME=$(hostname);
skip_gui_install=no

trap "" TSTP # Disable Ctrl-Z


if echo "$thisdir" | grep -q -s ^/ || echo "$thisdir" | grep -q -s ^~ ; then
# absolute path
   fullpath="$thisdir"
else
# relative path 
   runningdir=`pwd`
   fullpath="$runningdir/$thisdir"
fi
check_runningdir

system_cpu=`uname -m`
if [ "$system_cpu" = "x86_64" ] || [ "$system_cpu" = "amd64" ]; then
    my_arch=32e
else
    my_arch=32
fi

if [ $(uname) != "FreeBSD" ] && [ -f "/sbin/ldconfig" ]; then
    if [ "$my_arch" = "32" ]; then
        libz_exist=`/sbin/ldconfig -p | grep libz.so.1 | cut -d'>' -f2`
    elif [ "$my_arch" = "32e" ]; then
        libz_exist=`/sbin/ldconfig -p | grep libz.so.1 | grep x86-64 | cut -d'>' -f2`
    else
        libz_exist=`/sbin/ldconfig -p | grep libz.so.1 | grep IA-64 | cut -d'>' -f2`
    fi

    libz_exist="${libz_exist## }"
    libz_exist="${libz_exist%% }"
    if [ ! -f "$libz_exist" ]; then
        libz_exist=""
    fi
fi

unset libz_path
unset libqt_path

cli_mode_params=""
params=""
[ "$thisexec" = "uninstall.sh" ] && pset_mode="uninstall"
uninstall_detector="--PSET_MODE uninstall"
cmdline="$@"
if test "${cmdline#*$uninstall_detector}" != "$cmdline"; then
    pset_mode="uninstall"
else
    [ "$pset_mode" = "uninstall" ] && params="$params --PSET_MODE=uninstall"
fi

parse_cmd_parameters "$@"

[ "$(uname)" = "FreeBSD" ] && skip_cpu_check="yes"
if [ "$skip_cpu_check" != "yes" ]; then
    check_cpu_model
fi

#define and check temporary dir
if [ -z "$user_tmp" ]; then
    if [ -z "$TMPDIR" ]; then    
        user_tmp="/tmp"
    else
        if [ -d "$TMPDIR" ]; then
            user_tmp=$TMPDIR
        else
            user_tmp="/tmp"
        fi
    fi
fi

if ! echo "$user_tmp" | grep -q -s ^/ && ! echo "$user_tmp" | grep -q -s ^~ ; then
   user_tmp="`pwd`/$user_tmp"
fi

[ -z "${check_only}" ] && temp_folder=$(mktemp -d "$user_tmp/install.XXXXXX" 2>/dev/null)

if [ -z "$download_tmp" ]; then
    if [ "$(uname)" = "Darwin" ]; then
        download_tmp=$HOME/Downloads
    else
        download_tmp=$user_tmp
    fi
fi

params="$params --PRODUCT_ID \"$PRODUCT_ID\""

prepare_pset_binary

# check selinux
if [ "$skip_selinux_check" != "yes" ]; then
    SELINUXENABLED_CMD=`which selinuxenabled 2>/dev/null`
    SELINUXGETBOOL_CMD=`which getsebool 2>/dev/null`
    SELINUXSETBOOL_CMD=`which setsebool 2>/dev/null`
    if [ -z "$SELINUXGETBOOL_CMD" ]; then
        if [ -f "/usr/sbin/getsebool" ]; then
            SELINUXGETBOOL_CMD="/usr/sbin/getsebool"
        fi
    fi
    if [ -z "$SELINUXSETBOOL_CMD" ]; then
        if [ -f "/usr/sbin/setsebool" ]; then
            SELINUXSETBOOL_CMD="/usr/sbin/setsebool"
        fi
    fi
    if [ -z "$SELINUXENABLED_CMD" ] ; then
        SELINUX_PATH="/etc/sysconfig/selinux"
        
        if [ -e "$SELINUX_PATH" ] ; then
            SELINUXENABLED="y"
            [ ! -z `cat "$SELINUX_PATH" | grep "SELINUX=disabled"` ] && SELINUXENABLED=""
            [ ! -z `cat "$SELINUX_PATH" | grep "SELINUX=permissive"` ] && SELINUXENABLED=""
        fi
    else
        $SELINUXENABLED_CMD
        [ $? -eq 0 ] && SELINUXENABLED="y"
        if [ -e "$SELINUX_PATH" ] ; then
            [ ! -z `cat "$SELINUX_PATH" | grep "SELINUX=permissive"` ] && SELINUXENABLED=""
        fi
    fi

    if [ "$SELINUXENABLED" = "y" ] ; then
        if [ -z "$SELINUXGETBOOL_CMD" ] || [ -z "$SELINUXSETBOOL_CMD" ]; then
            echo "Your system doesn't allow to determine and change Security-enhanced Linux* (SELinux) settings." \
                 "Please ensure that SELinux utilities 'getsebool' and 'setsebool' are installed on the system" \
                 "and available via PATH variable. Then start installation again."
            echo ""
            echo "Quitting!"
            exit $EXIT_CODE_CANCEL
        fi
    
        if [ "off" = "$( ${SELINUXGETBOOL_CMD} allow_execmod | cut -d' ' -f3)" ] ||
           [ "off" = "$( ${SELINUXGETBOOL_CMD} allow_execstack | cut -d' ' -f3)" ]; then
            echo "Your system is protected with Security-enhanced Linux* (SELinux). " \
                 "Initial product installation and licensing requires that SELinux variables \"allow_execmod\" and \"allow_execstack\" are set to \"on\"." \
                 "In your current set up at least one of these variables is set to \"off\", this may prevent activation of the product."
            echo ""
            echo "You may temporary disable this security setting by calling"
            echo "  setsebool allow_execmod on"
            echo "  setsebool allow_execstack on"
            echo "under root account."
            echo ""
            echo "No reboot will be required."
            echo ""
            echo "More information about SELinux can be found at http://www.nsa.gov/research/selinux/index.shtml"
            echo ""
            echo "Quitting!"
            exit $EXIT_CODE_CANCEL
        fi
    fi
fi


#check if started under root account
[ -z "$UID" ] && UID=$(id -ru);
#if yes, no root-nonroot dialog will be shown
[ $UID -eq 0 ] && skip_uid_check=yes

if [ "$pset_mode" = "uninstall" ]; then
    show_sudo_dialog=0
    cache_dir=""
    if [ "$(uname)" = "Darwin" ]; then
        if [ $UID -eq 0 ]; then
            cache_dir="/opt/intel/ism/db/history/settings/"
        else
            cache_dir="$HOME/intel/ism/db/history/settings/"
        fi
    fi

    # check uninstall configuration file
    if [ -f "$cache_dir$pset_config_folder/uninstall.ini" ]; then
        INSTALL_MODE=$(cat "$cache_dir$pset_config_folder/uninstall.ini" | grep INSTALL_MODE= |  cut -d'=' -f2)
        ROOT_INSTALLATION=$(cat "$cache_dir$pset_config_folder/uninstall.ini" | grep ROOT_INSTALLATION= |  cut -d'=' -f2)
        NONRPM_DB_DIR=$(cat "$cache_dir$pset_config_folder/uninstall.ini" | grep NONRPM_DB_DIR= |  cut -d'=' -f2)

        # if configuration file is not bad, use it's content to detect if we need to show sudo_dialog
        if [ -n "$INSTALL_MODE" ]; then
            if [ "RPM" = "$INSTALL_MODE" -a $UID -ne 0 -o "yes" = "$ROOT_INSTALLATION" -a  $UID -ne 0 ]; then
                show_sudo_dialog=1
            fi
            params="$params --INSTALL_MODE=$INSTALL_MODE"
        fi
        if [ -n "$NONRPM_DB_DIR" ]; then
            params="$params --nonrpm_db_dir=$NONRPM_DB_DIR"
        fi

        if [ $show_sudo_dialog -eq 1 ] && ! can_escalate_privileges; then
            echo "Uninstallation program has detected that the product has been previously installed using root privileges."
            echo "Root or sudo permissions are required to continue uninstall of this product, but uninstallation program is unable"
            echo "to escalate privileges as the current user does not belong to 'wheel' group."
            echo ""
            echo "To continue uninstallation, please add user to this group by running the command:"
            echo "  FreeBSD: pw usermod $USER -G wheel"
            echo "or run this script under root account."
            exit $EXIT_CODE_CANCEL
        fi
    else
        [ $UID -ne 0 ] && show_sudo_dialog=1
    fi
else
    show_sudo_dialog=1
fi

# if we still here, check again
if [ $show_sudo_dialog -eq 1 ] && ! can_escalate_privileges; then
    # It's not possible to escalate priviledges as current user does not belong to 'wheel' group.
    # Continuing with current user privileges
    show_sudo_dialog=0
fi

#add all layers to LD_LIBRARY_PATH
layers_path=""
for layer in "$pset_config_folder/"*.cab; do
    layer_file=$(basename "$layer");
    layer_name=${layer_file%.*};
    layers_path="${layers_path}:${temp_folder}/${layer_name}"
done

[ "$(uname)" != "Darwin" ] && export LD_LIBRARY_PATH="${layers_path}:${LD_LIBRARY_PATH}"
[ "$(uname)" = "Darwin" ] && export DYLD_LIBRARY_PATH="${layers_path}:${DYLD_LIBRARY_PATH}"

[ "yes" = "${check_only}" ] && exit 0

root_nonroot=
[ "yes" != "${skip_gui_install}" ] && [ "yes" != "${skip_uid_check}" ] && [ $show_sudo_dialog -eq 1 ] && root_nonroot="--RUN_MODE=root_nonroot"

if [ "yes" != "${skip_gui_install}" ]; then
    export QTDIR=
    export QT_PLUGIN_PATH=
    if [ "$(uname)" != "Darwin" ]; then
        setxkbmap -print >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            export QT_XKB_CONFIG_ROOT=/usr/share/X11/xkb
            export XKB_DEFAULT_RULES=base
        fi
    fi
    "$pset_engine_binary" --tmp_dir "$user_tmp" --TEMP_FOLDER "$temp_folder" --download_dir "$download_tmp" $params $root_nonroot 2>/dev/null
    exit_code=$?
fi

if [ "$exit_code" = "$EXIT_CODE_GUI_RUN_ERROR" ] || [ "$exit_code" = "134" ]; then
    [ "$exit_code" = "134" ] && echo -e "\e[1A\e[1A\e[2K"
    echo "Cannot run setup in graphical mode."
    echo "Setup will be continued in command-line mode."
    echo ""
    skip_gui_install=yes
fi

if [ "$UID" -ne 0 ] && [ "yes" = "${skip_gui_install}" ] && [ "yes" != "$skip_uid_check" ] && [ $show_sudo_dialog -eq 1 ]; then
    [ "$(uname)" != "Darwin" ] && [ "yes" != "${minimal_launch}" ] && get_strings
    if [ "yes" = "$silent_mode" ] && [ "$pset_mode" = "uninstall" ]; then
        echo "$LI_root_permissions_required_warning"
        exit $EXIT_CODE_CANCEL
    fi
    cli_root_nonroot_dialog
fi

if [ "yes" = "${skip_gui_install}" ]; then
    if [ ! -z "$pset_engine_cli_binary" ]; then
        "$pset_engine_cli_binary" --tmp_dir "$user_tmp" --TEMP_FOLDER "$temp_folder" --download_dir "$download_tmp" $params
        exit_code=$?
    else
        echo "Missing install binary file. Please check the package and try again."
    fi
fi

[ "yes" = "${minimal_launch}" ] && rm -rf $temp_folder >/dev/null 2>&1
[ "$(uname)" != "Darwin" ] && [ "$pset_mode" = "uninstall" ] && rm -rf $temp_dir >/dev/null 2>&1

## CD Eject Issue
if [ -f "$fullpath"/cd_eject.sh ]; then
    if [ -z "$skip_cd_eject" ]; then
        "$fullpath"/cd_eject.sh $PPID
        exit $exit_code
    fi
fi
exit $exit_code
