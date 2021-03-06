        # don't set prompt if this is not interactive shell
        [[ $- != *i* ]]  &&  return

###################################################################   CONFIG

        #####  read config file if any.

        unset make_color_ok make_color_dirty jobs_color_bkg jobs_color_stop slash_color slash_color_readonly at_color at_color_remote
        unset command_time_color clock_color
        unset dir_color rc_color user_id_color root_id_color init_vcs_color clean_vcs_color
        unset modified_vcs_color added_vcs_color untracked_vcs_color deleted_vcs_color op_vcs_color detached_vcs_color hex_vcs_color conflicted_vcs_color
        unset rawhex_len

        conf=git-prompt.conf;                   [[ -r $conf ]]  && . $conf
        conf=/etc/git-prompt.conf;              [[ -r $conf ]]  && . $conf
        conf=~/.git-prompt.conf;                [[ -r $conf ]]  && . $conf
        conf=~/.config/git-prompt.conf;         [[ -r $conf ]]  && . $conf
        unset conf


        #####  set defaults if not set

        git_module=${git_module:-on}
        svn_module=${svn_module:-off}
        hg_module=${hg_module:-on}
        vim_module=${vim_module:-on}
        virtualenv_module=${virtualenv_module:-on}
        battery_module=${battery_module:-off}
        make_module=${make_module:-off}
        jobs_module=${jobs_module:-on}
        rc_module=${rc_module:-on}
        command_time_module=${command_time_module:-on}
        load_module=${load_module:-on}
        clock_module=${clock_module:-off}
        sudo_module=${sudo_module:-off}
        error_bell=${error_bell:-off}
        cwd_cmd=${cwd_cmd:-\\w}

        default_host_abbrev_mode=${default_host_abbrev_mode:-delete}
        default_id_abbrev_mode=${default_id_abbrev_mode:-delete}

        prompt_modules_order=${prompt_modules_order:-RC LOAD CTIME VIRTUALENV VCS SUDO WHO_WHERE JOBS BATTERY CWD MAKE}

        #### check for battery files, make, disable corresponding module if not installed
        # FIXME check other possible locations (BAT1, /proc ?)
        if [[ ! -f /sys/class/power_supply/BAT0/present || ! $(< /sys/class/power_supply/BAT0/present) ]]; then
            battery_module=off
        fi
        if [[ -z $(which make 2> /dev/null) ]]; then
            make_module=off
        fi

        #### dir, rc, root color
        cols=`tput colors`                              # in emacs shell-mode tput colors returns -1
        if [[ -n "$cols" && $cols -ge 8 ]];  then       #  if terminal supports colors
                dir_color=${dir_color:-CYAN}
                slash_color=${slash_color:-CYAN}
                slash_color_readonly=${slash_color_readonly:-MAGENTA}
                prompt_color=${prompt_color:-white}
                rc_color=${rc_color:-red}
                virtualenv_color=${virtualenv_color:-green}
                user_id_color=${user_id_color:-blue}
                root_id_color=${root_id_color:-magenta}
                at_color=${at_color:-green}
                at_color_remote=${at_color_remote:-RED}
                jobs_color_bkg=${jobs_color:-yellow}
                jobs_color_stop=${jobs_color:-red}
                make_color_ok=${make_color_ok:-BLACK}
                make_color_dirty=${make_color_dirty:-RED}
                command_time_color=${command_time_color:-YELLOW}
                clock_color=${clock_color:-BLACK}
                sudo_color=${sudo_color:-RED}

        else                                            #  only B/W
                dir_color=${dir_color:-bw_bold}
                rc_color=${rc_color:-bw_bold}
        fi
        unset cols

        #### prompt character, for root/non-root
        prompt_char=${prompt_char:-'>'}
        root_prompt_char=${root_prompt_char:-'>'}

        #### vcs colors
                 init_vcs_color=${init_vcs_color:-WHITE}        # initial
                clean_vcs_color=${clean_vcs_color:-blue}        # nothing to commit (working directory clean)
             modified_vcs_color=${modified_vcs_color:-red}      # Changed but not updated:
                added_vcs_color=${added_vcs_color:-green}       # Changes to be committed:
            untracked_vcs_color=${untracked_vcs_color:-BLUE}    # Untracked files:
              deleted_vcs_color=${deleted_vcs_color:-yellow}    # Deleted files:
           conflicted_vcs_color=${conflicted_vcs_color:-CYAN}   # Conflicted files:
                   op_vcs_color=${op_vcs_color:-MAGENTA}
             detached_vcs_color=${detached_vcs_color:-RED}

                  hex_vcs_color=${hex_vcs_color:-BLACK}         # gray


        max_file_list_length=${max_file_list_length:-100}
        short_hostname=${short_hostname:-off}
        upcase_hostname=${upcase_hostname:-on}
        count_only=${count_only:-off}
        rawhex_len=${rawhex_len:-5}
        hg_revision_display=${hg_revision_display:-none}
        hg_multiple_heads_display=${hg_multiple_heads_display:-on}
        command_time_threshold=${command_time_threshold:-15}
        clock_style=${clock_style:-analog}
        clock_alert_interval=${clock_alert_interval:-30}
        enable_utf8=${enable_utf8:-on}

        if [[ -z "$load_colors" || -z "$load_thresholds" || ${#load_colors[@]} -ne ${#load_thresholds[@]} ]]; then
            load_colors=(BLACK red RED whiteonred)
            load_thresholds=(100 200 300 400)
        fi
        load_display_style=${load_display_style:-bar}


        aj_max=20


#####################################################################  post config

        ################# make PARSE_VCS_STATUS
        unset PARSE_VCS_STATUS
        [[ $git_module = "on" ]]   &&   type git >&/dev/null   &&   PARSE_VCS_STATUS+="parse_git_status"
        [[ $svn_module = "on" ]]   &&   type svn >&/dev/null   &&   PARSE_VCS_STATUS+="${PARSE_VCS_STATUS+||}parse_svn_status"
        [[ $hg_module  = "on" ]]   &&   type hg  >&/dev/null   &&   PARSE_VCS_STATUS+="${PARSE_VCS_STATUS+||}parse_hg_status"
                                                                    PARSE_VCS_STATUS+="${PARSE_VCS_STATUS+||}return"

        ### determining svn version information
        ### In svn versions 1.7 and above there is only a single .svn directory
        ### in the repository root, while before there was a .svn in every subdirectory.
        ### Here we determine and save svn version information 
        ### and use the appropriate method in the runtime module
        ### However, if the "svnversion" utility is installed, 
        ### we use its output instead.
        if [[ $PARSE_VCS_STATUS =~ "svn" ]]; then
            unset svn_method
            type svnversion >&/dev/null && svn_method="svnversion"
            svn_version_str=$(svn --version 2> /dev/null | head -1 | sed -ne 's/.* \([0-9]\)\.\([0-9]\{1,2\}\).*/\1\2/p')
            if [[ "$svn_method" != "svnversion" ]]; then
                if [[ $svn_version_str > 16 ]]; then
                    svn_method="info"
                else
                    svn_method="dotsvn"
                fi
            fi
            unset svn_version_str
        fi

        ################# terminfo colors-16
        #
        #       black?    0 8
        #       red       1 9
        #       green     2 10
        #       yellow    3 11
        #       blue      4 12
        #       magenta   5 13
        #       cyan      6 14
        #       white     7 15
        #
        #       terminfo setaf/setab - sets ansi foreground/background
        #       terminfo sgr0 - resets all attributes
        #       terminfo colors - number of colors
        #
        #################  Colors-256
        #  To use foreground and background colors:
        #       Set the foreground color to index N:    \033[38;5;${N}m
        #       Set the background color to index M:    \033[48;5;${M}m
        # To make vim aware of a present 256 color extension, you can either set
        # the $TERM environment variable to xterm-256color or use vim's -T option
        # to set the terminal. I'm using an alias in my bashrc to do this. At the
        # moment I only know of two color schemes which is made for multi-color
        # terminals like urxvt (88 colors) or xterm: inkpot and desert256,

        ### if term support colors,  then use color prompt, else bold

              black='\['`tput sgr0; tput setaf 0`'\]'
                red='\['`tput sgr0; tput setaf 1`'\]'
              green='\['`tput sgr0; tput setaf 2`'\]'
             yellow='\['`tput sgr0; tput setaf 3`'\]'
               blue='\['`tput sgr0; tput setaf 4`'\]'
            magenta='\['`tput sgr0; tput setaf 5`'\]'
               cyan='\['`tput sgr0; tput setaf 6`'\]'
              white='\['`tput sgr0; tput setaf 7`'\]'

              BLACK='\['`tput setaf 0; tput bold`'\]'
                RED='\['`tput setaf 1; tput bold`'\]'
              GREEN='\['`tput setaf 2; tput bold`'\]'
             YELLOW='\['`tput setaf 3; tput bold`'\]'
               BLUE='\['`tput setaf 4; tput bold`'\]'
            MAGENTA='\['`tput setaf 5; tput bold`'\]'
               CYAN='\['`tput setaf 6; tput bold`'\]'
              WHITE='\['`tput setaf 7; tput bold`'\]'

         whiteonred='\['`tput setaf 7; tput setab 1; tput bold`'\]'

                dim='\['`tput sgr0; tput setaf p1`'\]'  # half-bright

            bw_bold='\['`tput bold`'\]'

        on=''
        off=': '
        bell="\[`eval ${!error_bell} tput bel`\]"
        colors_reset='\['`tput sgr0`'\]'

        # replace symbolic colors names to raw terminfo strings
                 init_vcs_color=${!init_vcs_color}
           conflicted_vcs_color=${!conflicted_vcs_color}
             modified_vcs_color=${!modified_vcs_color}
            untracked_vcs_color=${!untracked_vcs_color}
                clean_vcs_color=${!clean_vcs_color}
                added_vcs_color=${!added_vcs_color}
                   op_vcs_color=${!op_vcs_color}
             detached_vcs_color=${!detached_vcs_color}
              deleted_vcs_color=${!deleted_vcs_color}
                  hex_vcs_color=${!hex_vcs_color}

                      dir_color=${!dir_color}
                    slash_color=${!slash_color}
           slash_color_readonly=${!slash_color_readonly}
                   prompt_color=${!prompt_color}
                       rc_color=${!rc_color}
               virtualenv_color=${!virtualenv_color}
                  user_id_color=${!user_id_color}
                  root_id_color=${!root_id_color}
                       at_color=${!at_color}
                at_color_remote=${!at_color_remote}


        unset PROMPT_COMMAND

        # assemble prompt command string based on the module order specified above

        # RC, LOAD, CLOCK, CTIME, VIRTUALENV and VCS has to be flanked by spaces on either side
        # except if they are at the start or end of the sequence.
        # excess spaces (which may occur if some of the modules produce empty output)
        # will be trimmed at runtime, in the prompt_command_function.

        prompt_command_string=$(echo $prompt_modules_order |
            sed '
                s/RC/\$space\$rc\$space/;
                s/LOAD/$space$load_indicator$space/;
                s/CLOCK/$space$clock_indicator$space/;
                s/CTIME/$space$command_time$space/;
                s/VIRTUALENV/\$space\$virtualenv_string\$space/;
                s/VCS/\$space\$head_local\$space/;
                s/WHO_WHERE/\$color_who_where\$colors_reset/;
                s/JOBS/\$jobs_indicator/;
                s/BATTERY/\$battery_indicator/;
                s/CWD/\$dir_color\$cwd/;
                s/MAKE/\$make_indicator/;
                s/SUDO/\$sudo_marker/;
                s/ //g;
                s/\$space\$space/\$space/g;
                s/^\$space//;
                s/\$space$//;
                s/\$space/ /g;
                ')

        # save startup and midnight timestamp for clock
        _gp_clock_timestamp_start=$(date +%s)
        _gp_clock_timestamp_midnight=$(date -d 0:0 +%s)
        _gp_clock_timestamp_last=${_gp_clock_timestamp_start}

        ####################################################################  MARKERS
        ellipse_marker_utf8="…"
        ellipse_marker_plain="..."

_gp_check_utf8() {
        if [[ $enable_utf8 == "on" && ("$LC_CTYPE $LC_ALL $LANG" =~ "UTF" || $LANG =~ "utf") && $TERM != "linux" ]];  then
                utf8_prompt=1
                ellipse_marker=$ellipse_marker_utf8
        else
                utf8_prompt=
                ellipse_marker=$ellipse_marker_plain
        fi
}

_gp_check_utf8

export who_where


cwd_truncate() {
        # based on:   https://www.blog.montgomerie.net/pwd-in-the-title-bar-or-a-regex-adventure-in-bash

        # arg1: max path lenght
        # returns abbrivated $PWD  in public "cwd" var

        cwd=${PWD/$HOME/\~}             # substitute  "~"

        case $1 in
                full)
                        return
                        ;;
                last)
                        cwd=${PWD##/*/}
                        [[ $PWD == $HOME ]]  &&  cwd="~"
                        return
                        ;;
                *)
                        # if bash < v3.2  then don't truncate
			if [[  ${BASH_VERSINFO[0]} -eq 3   &&   ${BASH_VERSINFO[1]} -le 1  || ${BASH_VERSINFO[0]} -lt 3 ]] ;  then
				return
			fi
                        ;;
        esac

        # split path into:  head='~/',  truncateble middle,  last_dir

        local cwd_max_length=$1
        # expression which bash-3.1 or older can not understand, so we wrap it in eval
        exp31='[[ "$cwd" =~ (~?/)(.*/)([^/]*)$ ]]'
        if  eval $exp31 ;  then  # only valid if path have more then 1 dir
                local path_head=${BASH_REMATCH[1]}
                local path_middle=${BASH_REMATCH[2]}
                local path_last_dir=${BASH_REMATCH[3]}

                local cwd_middle_max=$(( $cwd_max_length - ${#path_last_dir} ))
                [[ $cwd_middle_max < 0  ]]  &&  cwd_middle_max=0


		# trunc middle if over limit
                if   [[ ${#path_middle}   -gt   $(( $cwd_middle_max + ${#ellipse_marker} + 5 )) ]];   then

			# truncate
			middle_tail=${path_middle:${#path_middle}-${cwd_middle_max}}

			# trunc on dir boundary (trunc 1st, probably tuncated dir)
			exp31='[[ $middle_tail =~ [^/]*/(.*)$ ]]'
			eval $exp31
			middle_tail=${BASH_REMATCH[1]}

			# use truncated only if we cut at least 4 chars
			if [[ $((  ${#path_middle} - ${#middle_tail}))  -gt 4  ]];  then
				cwd=$path_head$ellipse_marker$middle_tail$path_last_dir
			fi
                fi
        fi
        return
 }


set_shell_label() {
        local param full
        full="$plain_who_where $@"
        short="$*"

        # hack to replace garbled bash command under mc on some systems
        if [[ "$short" == ". /usr/libexec/mc/mc-wrapper.sh" ]]; then
             short="mc"
             full="$plain_who_where $short"
        fi

        xterm_label() {
             local args="$*"
             printf "\033]0;%s\007" "${args:0:200}"
        }

        screen_label() {

            # FIXME $STY not inherited though "su -"
            if [[ "$STY" ]]; then
                # workaround screen UTF-8 bug
                short=${param//$ellipse_marker/$ellipse_marker_plain}
                full=${full//$ellipse_marker/$ellipse_marker_plain}
            fi

            if [[ "$TMUX" ]]; then
                full="$plain_who_where${_gp_tmux_session:+|${_gp_tmux_session}} $short"
            fi

            # FIXME: run this only if screen is in xterm (how to test for this?)
            xterm_label "$full"

            printf "\033k%s\033\\" "$short"
        }

        if [[ -n "$STY" || -n "$TMUX" ]]; then
            # in this case, do not prepend host name, 
            # because screen/tmux statusbar should display it only once -
            # displaying it in every window name would waste space
            screen_label "$short"
        else
            case $TERM in
                screen*)
                         # display host name in window title if we're inside screen or tmux locally,
                         # and ssh'd to a remote server
                         if [[ -n ${SSH_CLIENT} || -n ${SSH2_CLIENT} || -n ${SSH_CONNECTION} ]]; then
                             short="@$host:$short"
                         fi
                         screen_label "$short"
                         ;;

                xterm* | rxvt* | gnome-* | konsole | eterm | wterm )
                         # is there a capability which we can to test
                         # for "set term title-bar" and its escapes?
                         xterm_label "$full"
                         ;;

                *)       ;;
            esac
        fi
 }

    export -f set_shell_label

###################################################### ID (user name)
_gp_get_id() {
        id=`id -un`

        # abbreviate user name if needed
        if   [[ "$default_id_abbrev_mode" == "delete" ]]
        then
            id=${id#$default_user}
        elif [[ "$default_id_abbrev_mode" == "abbrev" ]]
        then
            # only abbreviate if the abbreviated string is actually shorter than the full one
            if [[ "$id" == "$default_user" && ${#id} -ge $((${#ellipse_marker} + 1)) ]]
            then
                id="${id:0:1}$ellipse_marker"
            fi
        #else
            # keep full user name
        fi
}

_gp_get_id

########################################################### TTY
_gp_get_tty() {
        local tty
        tty=$(tty)
        tty=${tty/\/dev\/pts\//p}   # RH tty devs
        tty=${tty/\/dev\/tty/}
        tty=${tty/\/dev\/vc\//vc}   # gentoo tty devs

        # replace tty name with screen number
        # however, "screen" as $TERM may also mean tmux
        if [[ "$TERM" =~ "screen" ]] ;  then
            if [[ "$STY" ]]; then
                tty="$WINDOW"
            elif [[ -n $TMUX && -n $TMUX_PANE ]]; then
                # get tmux session name so that we can include it in the window title
                # and window number, to display it in the prompt
                # TODO configurable prompt marker
                # we have to do it like this, because session name may contain spaces
                local sep tmux_info oldIFS
                sep=$'\x1f'
                tmux_info=$(tmux display-message -t $TMUX_PANE -p "#S${sep}#I" 2> /dev/null)
                oldIFS="$IFS"
                IFS="$sep"
                local -a tmux_array
                tmux_array=($tmux_info)
                IFS="$oldIFS"
                _gp_tmux_session=${tmux_array[0]}
                tty=${tmux_array[1]}
            else
                tty=
            fi

            # if we start an ssh connection from within a screen/tmux session,
            # the "screen" $TERM setting tends to be preserved.
            # In this case we don't want the tty displayed (it would be a misleading "0"),
            # unless there is an actual screen/tmux session on the server too.
            if [[ -n "$tty" ]]; then
                # replace tty number with circled numbers
                if [[ $utf8_prompt ]]; then
                    local -a circled_digits=(⓪ ① ② ③ ④ ⑤ ⑥ ⑦ ⑧ ⑨ ⑩ ⑪ ⑫ ⑬ ⑭ ⑮ ⑯ ⑰ ⑱ ⑲ ⑳)
                    if [[ "$tty" -ge 0 && "$tty" -le 20 ]]; then
                        tty="${circled_digits[$tty]} "
                    fi
                else
                    tty=" $tty"
                fi
            fi
        fi

        # we don't need tty name under X11
        case $TERM in
            xterm* | rxvt* | gnome-terminal | konsole | eterm* | wterm | cygwin)  tty= ;;
            *);;
        esac

        _gp_tty="$tty"
}

_gp_get_tty

        ########################################################### HOST
        ### we don't display home host/domain  $SSH_* set by SSHD or keychain

        # How to find out if session is local or remote? Working with "su -", ssh-agent, and so on ?

        ## is sshd our parent?
        # if    { for ((pid=$$; $pid != 1 ; pid=`ps h -o pid --ppid $pid`)); do ps h -o command -p $pid; done | grep -q sshd && echo == REMOTE ==; }
        #then

_gp_get_host() {
        if [[ -n ${SSH_CLIENT} || -n ${SSH2_CLIENT} || -n ${SSH_CONNECTION} ]]; then
            probably_ssh_session=1
            at_color_cur=$at_color_remote
        else
            probably_ssh_session=
            at_color_cur=$at_color
        fi

        host=${HOSTNAME}
        if [[ $short_hostname = "on" ]]; then
			if [[ "$(uname)" =~ "CYGWIN" ]]; then
				host=`hostname`
			else
				host=`hostname -s`
			fi
        fi

        uphost=`echo ${host} | tr a-z-. A-Z_`

        host_color=${uphost}_host_color
        host_color=${!host_color}
        if [[ -z $host_color && -x /usr/bin/cksum ]] ;  then
                cksum_color_no=`echo $uphost | cksum  | awk '{print $1%6}'`
                color_index=(green yellow blue magenta cyan white)              # FIXME:  bw,  color-256
                host_color=${color_index[cksum_color_no]}
        fi

        # abbreviate host name if needed
        # disregard setting and display full host if session is remote
        if   [[ "$default_host_abbrev_mode" == "delete" && -z $probably_ssh_session ]]
        then
            host=${host#$default_host}
        elif [[ "$default_host_abbrev_mode" == "abbrev" && -z $probably_ssh_session ]]
        then
            # only abbreviate if the abbreviated string is actually shorter than the full one
            if [[ "$host" == "$default_host" && ${#host} -ge $((${#ellipse_marker} + 1)) ]]
            then
                host="${host:0:1}$ellipse_marker"
            fi
        else
            # set upcase hostname if needed
            if [[ $upcase_hostname = "on" ]]; then
                host=${uphost}
            fi
        fi

        host_color=${!host_color}

        # we might already have short host name
        [[ -n $default_domain ]] && host=${host%.$default_domain}

        unset probably_ssh_session
}

_gp_get_host

#################################################################### WHO_WHERE
        #  [[user@]host[-tty]]

_gp_set_who_where() {
        if [[ -n $id  || -n $host ]] ;   then
                [[ -n $id  &&  -n $host ]]  &&  at='@'  || at=''
                color_who_where="${id//\\/\\\\}${host:+$at_color_cur$at$host_color$host}${_gp_tty:+$_gp_tty}"
                plain_who_where="${id}$at$host"

                # if root then make it root_color
                if [ "$id" == "root" ]  ; then
                        user_id_color=$root_id_color
                        prompt_char="$root_prompt_char"
                fi

                color_who_where="$user_id_color$color_who_where$colors_reset"
        else
                color_who_where=''
        fi

        # There are at least two separate problems with mc:
        # it clobbers $PROMPT_COMMAND, so none of the dynamically generated
        # components can work,
        # and it swallows escape sequences, so colors don't work either.
        # Here we try to salvage some of the functionality for shells within mc.
        #
        # specifically exclude emacs, want full when running inside emacs
        if [[ -z "$TERM" || ("$TERM" = "dumb" && -z "$INSIDE_EMACS") || -n "$MC_SID" ]]; then
            unset PROMPT_COMMAND
            if [[ -n $id  || -n $host ]] ;   then
                PS1="$color_who_where:\w$prompt_char "
            else
                PS1="\w$prompt_char "
            fi
            return 1
        fi
}

_gp_set_who_where

# exit if in mc (see above)
[[ $? -ne 0 ]] && return 1

create_battery_indicator () {
        # if not a laptop: :
        # if laptop on AC, not charging: ⚡ 
        # if laptop on AC, charging: ▕⚡▏
        # if laptop on battery: one of ▕▁▏▕▂▏▕▃▏▕▄▏▕▅▏▕▆▏▕▇▏▕█▏
        # color: red if power < 30 %, else normal

        local battery_present battery_status battery_percent battery_color battery_pwr_index tmp
        local -a battery_diagrams
        battery_present=$(< /sys/class/power_supply/BAT0/present)

        if [[ $battery_present ]]; then
            battery_status=$(< /sys/class/power_supply/BAT0/status)
            battery_percent=$(< /sys/class/power_supply/BAT0/capacity)
            if [[ "$battery_status" =~ "Discharging" ]]; then
                if [[ $utf8_prompt ]]; then
                    battery_diagrams=( ▕▁▏ ▕▂▏ ▕▃▏ ▕▄▏ ▕▅▏ ▕▆▏ ▕▇▏ ▕█▏ )
                    battery_pwr_index=$(($battery_percent/13))
                    battery_indicator=${battery_diagrams[battery_pwr_index]}
                else
                    battery_indicator="|$battery_percent|"
                fi
            elif [[ "$battery_status" =~ "Charging" ]]; then
                if [[ $utf8_prompt ]]; then
                    battery_indicator="▕⚡▏"
                else
                    battery_indicator="|^|"
                fi
            else
                if [[ $utf8_prompt ]]; then
                    battery_indicator=" ⚡ "
                else
                    battery_indicator=" = "
                fi
            fi

            if [[ $battery_percent -ge 31 ]]; then
                battery_color=$colors_reset
            elif [[ $battery_percent -ge 11 ]]; then
                battery_color=$RED
            else
                battery_color=$whiteonred
            fi
        else
            battery_indicator=":"
            battery_color=$colors_reset
        fi
        battery_indicator="$battery_color$battery_indicator$colors_reset"
}

create_jobs_indicator() {
        # background jobs ⚒⚑⚐⚠
        local jobs_bkg=$(jobs -r)
        local jobs_stop=$(jobs -s)
        if [[ -n $jobs_bkg || -n $jobs_stop ]]; then
            if [[ $utf8_prompt ]]; then
                jobs_indicator="⚒"
            else
                jobs_indicator="%"
            fi
            if [[ -n $jobs_stop ]]; then
                jobs_indicator="${!jobs_color_stop}$jobs_indicator$colors_reset"
            else
                jobs_indicator="${!jobs_color_bkg}$jobs_indicator$colors_reset"
            fi
        else
            jobs_indicator=""
        fi
}

check_make_status() {

        make_indicator=""
        [[ $make_ignore_dir_list =~ $PWD ]] && return

        local myrc
        if [[ -e Makefile ]]; then
            if [[ $utf8_prompt ]]; then
                make_indicator="⚑"
            else
                make_indicator="*"
            fi
            make -q &> /dev/null
            myrc=$?
            if [[ $myrc -eq 0 ]]; then
                make_indicator="${!make_color_ok}$make_indicator"
            else
                make_indicator="${!make_color_dirty}$make_indicator"
            fi
        else
            make_indicator=""
        fi
}

meas_command_time() {
        if [[ ${_gp_timestamp} ]]; then
            local elapsed_time=$(($SECONDS - ${_gp_timestamp}))
            if [[ $elapsed_time -gt $command_time_threshold ]]; then
                command_time="${!command_time_color}${elapsed_time}s$colors_reset"
            fi
        fi
        unset _gp_timestamp
}

create_clock() {
        clock_indicator=""

        # this contrived calculation is done to avoid calling `date` every time
        local current_time time_of_day index
        current_time=$(($SECONDS + ${_gp_clock_timestamp_start}))

        if [[ $clock_alert_interval -gt 0 ]]; then
            [[ $(( ($current_time - ${_gp_clock_timestamp_last})/(60 * $clock_alert_interval) )) -eq 0 ]] && return
        fi

        if [[ $clock_style == "analog" && $utf8_prompt ]]; then
            # unicode clock face characters
            # U+1F550 (ONE OCLOCK) .. U+1F55B (TWELVE OCLOCK), for the plain hours
            # U+1F55C (ONE-THIRTY) .. U+1F567 (TWELVE-THIRTY), for the thirties
            local clockfaces=(🕧 🕐 🕜 🕑 🕝 🕒 🕞 🕓 🕟 🕔 🕠 🕕 🕡 🕖 🕢 🕗 🕣 🕘 🕤 🕙 🕥 🕚 🕦 🕛)
            time_of_day=$(( (${current_time} - ${_gp_clock_timestamp_midnight}) % 86400 ))
            index=$(( (($time_of_day - 900) % 43200) / 1800 ))
            clock_indicator="${!clock_color}${clockfaces[$index]}${colors_reset}"
        else
            clock_indicator="${!clock_color}\t${colors_reset}"
        fi 
        _gp_clock_timestamp_last=$current_time
}

create_load_indicator () {
        local load_color load_value load_str load_bar load_mark i j

        if [[ "$OSTYPE" =~ "linux" ]]; then
            local eol
            read load_str eol < /proc/loadavg
            load_str=${load_str## *}
        else
            load_str=$(uptime | sed -ne 's/.* load average: \([0-9]\.[0-9]\{1,2\}\).*/\1/p')
        fi
        load_value=${load_str/\./}
        load_value=$((10#$load_value))

        if [[ $load_value -le ${load_thresholds[0]} ]]; then
            load_indicator=""
            return
        fi

        for ((i = ${#load_thresholds[@]} ; i > 0 ; i--)); do
            j=$((i-1))
            if [[ $load_value -gt ${load_thresholds[$j]} ]]; then 
                load_color=${!load_colors[$j]}
                break
            fi
        done

        if [[ $utf8_prompt ]]; then
            load_mark="☢"
            if [[ $load_display_style == "bar" ]]; then
                local load_int=$((load_value / 100 - 1))
                local load_frac=$((load_value % 100))
                load_frac=$((load_frac / 12))
                local -a load_chars=( " " "▏" "▎" "▍" "▌" "▋" "▊" "▉" "█" )
            
                printf -v load_str "%${load_int}s"
                load_str=${load_str// /◙}
                load_str+=${load_chars[$load_frac]}
            fi
        else
            load_mark="L"
        fi

        if [[ $load_display_style == "markonly" ]]; then load_str= ; fi

        load_indicator="$load_color$load_mark$load_str$colors_reset"
}

create_sudo_marker() {
         sudo_marker=
         if [[ $utf8_prompt ]]; then
             sudo -nl &> /dev/null && sudo_marker="${!sudo_color}⚷$colors_reset"
         else
             sudo -nl &> /dev/null && sudo_marker="${!sudo_color}!$colors_reset"
         fi
}

parse_svn_status() {
        local svn_info_str myrc rev

        case $svn_method in
            svnversion)  rev=$(svnversion 2> /dev/null)
                         myrc=$?
                         [[ $myrc -ne 0 || "$rev" == "exported" || "$rev" =~ "Unversioned" ]] && return 1
                         ;;

            info)        svn_info_str=$(svn info 2> /dev/null)
                         myrc=$?
                         [[ $myrc -eq 0 ]]          || return 1
                         rev=${svn_info_str##*Revision: }
                         rev=${rev%%[[:space:]]*}
                         ;;

            dotsvn)      [[ -d .svn ]]              || return 1
                         svn_info_str=$(svn info 2> /dev/null)
                         myrc=$?
                         [[ $myrc -eq 0 ]]          || return 1
                         rev=${svn_info_str##*Revision: }
                         rev=${rev%%[[:space:]]*}
                         ;;

            *)           return 1
        esac

        vcs=svn

        ### get status

        unset status modified added clean init deleted untracked conflicted op detached
        eval `svn status 2>/dev/null | sed 's/\\\\/x/g' |
                sed -n '
                    s/^A...    \([^.].*\)/        added_files+=(\"\1\");/p
                    s/^M...    \([^.].*\)/     modified_files+=(\"\1\");/p
                    s/^R...    \([^.].*\)/               added=added;/p
                    s/^D...    \([^.].*\)/      deleted_files+=(\"\1\");/p
                    s/^C...    \([^.].*\)/   conflicted_files+=(\"\1\");/p
                    s/^\!...    \([^.].*\)/     deleted_files+=(\"\1\");/p
                    s/^\?...    \([^.].*\)/   untracked_files+=(\"\1\");/p
                '
        `

          modified=${modified_files[0]:+modified}
             added=${added_files[0]:+added}
           deleted=${deleted_files[0]:+deleted}
         untracked=${untracked_files[0]:+untracked}
        conflicted=${conflicted_files[0]:+conflicted}

        # TODO branch detection if standard repo layout

        [[ -z $modified   ]] && \
        [[ -z $untracked  ]] && \
        [[ -z $added      ]] && \
        [[ -z $deleted    ]] && \
        [[ -z $conflicted ]] && \
        clean=clean

        vcs_info=r$hex_vcs_color$rev$colors_reset
 }

parse_hg_status() {

        # ☿
        # Get all information we need in one go from hg log's output
        # if we're not in a hg directory, this takes exactly the same time as 'hg root' would do,
        # and if we're in a hg dir, we don't have to call 'hg branch' and 'hg id' separately.
        local id_str
        id_str=$(hg log --follow -l 1 --template '{rev}\x1f{node}\x1f{tags}\x1f{branches}\x1f{bookmarks}\x1f{phase}' 2> /dev/null) || return 1

        # This contrived way is necessary because branch names and tags can contain spaces.
        # The ASCII "Unit separator" \x1f was chosen as a "safe" separator character
        # because it was intended for exactly this purpose.
        # Nowadays nobody knows that such a character exists at all :)
        local oldIFS
        oldIFS="$IFS"
        IFS=$'\x1f'
        local -a id_array
        id_array=($id_str)
        IFS="$oldIFS"

        local branch bookmark num rev tags tip_regex not_uptodate phase
             num="${id_array[0]}"
             rev="${id_array[1]}"
            tags="${id_array[2]}"
          branch="${id_array[3]}"
        bookmark="${id_array[4]}"
           phase="${id_array[5]}"

        vcs=hg

        ### get status
        unset status modified added clean init deleted untracked op detached

        eval `hg status 2>/dev/null | sed 's/\\\\/x/g' |
                sed -n '
                        s/^M \([^.].*\)/     modified_files+=(\"\1\");/p
                        s/^A \([^.].*\)/        added_files+=(\"\1\");/p
                        s/^R \([^.].*\)/      deleted_files+=(\"\1\");/p
                        s/^\! \([^.].*\)/     deleted_files+=(\"\1\");/p
                        s/^\? \([^.].*\)/   untracked_files+=(\"\1\");/p
        '`

### EXPERIMENTAL: it is actually faster, especially for many files
#        eval `hg status 2>/dev/null |
#                perl -lne '
#                        push @{$x{substr($_,0,1)}}, substr($_,2);
#                        END {
#                            print qq/modified_files=(/,  (map {qq/ "$_" /} @{$x{M}}),             q/);/;
#                            print qq/added_files=(/,     (map {qq/ "$_" /} @{$x{A}}),             q/);/; 
#                            print qq/deleted_files=(/,   (map {qq/ "$_" /} @{$x{R}}, @{$x{"!"}}), q/);/;
#                            print qq/untracked_files=(/, (map {qq/ "$_" /} @{$x{"?"}}),           q/);/;
#                        }
#        '`


         modified=${modified_files[0]:+modified}
            added=${added_files[0]:+added}
          deleted=${deleted_files[0]:+deleted}
        untracked=${untracked_files[0]:+untracked}

        [[ -z $modified ]] && [[ -z $untracked ]] && [[ -z $added ]] && [[ -z $deleted ]] && clean=clean

        # older versions of hg log --template '{branch}' report empty if branch is default
        [[ -z $branch ]] && branch=default

        vcs_info=${branch/default/D}
        if [[ "$bookmark" ]] ;  then
                vcs_info+=/$bookmark
        fi

        if [[ $hg_multiple_heads_display == "on" ]]; then
            local hg_heads
            hg_heads=$(hg heads --template '{rev}\n' $branch 2> /dev/null | wc -l)

            if [[ $hg_heads -gt 1 ]]; then
                detached=detached
                local excl_mark='!'
                vcs_info="$detached_vcs_color$hg_heads$excl_mark$vcs_info"
            fi
        fi

        local hg_vcs_char hg_up_char
        if [[ $utf8_prompt ]]; then
            hg_vcs_char="☿"
            hg_up_char="⬆"
            case $phase in
                public)  phase="${green}⚌";; # ☻
                draft)   phase="${yellow}⚍";; # ☺
                secret)  phase="${red}⚏";; # ☹
                *)       phase="" ;;
            esac
        else
            hg_vcs_char=":"
            hg_up_char="^"
            phase=${phase:0:3}
            case $phase in
                public)  phase="${green}pub";;
                draft)   phase="${yellow}dra";;
                secret)  phase="${red}sec";;
                *)       phase="";;
            esac

        fi

        tip_regex=\\btip\\b
        if [[ ! $tags =~ $tip_regex ]]; then
            not_uptodate="$YELLOW$hg_up_char"
        fi

        local hg_revision
        case $hg_revision_display in
            id)    hg_revision=$rev
                   hg_revision="$hex_vcs_color$hg_vcs_char${hg_revision:0:$rawhex_len}"
                   ;;
            num)   hg_revision=$num
                   hg_vcs_char="#"
                   hg_revision="$hex_vcs_color$hg_vcs_char$hg_revision"
                   ;;
            *)     hg_revision="" ;;
        esac

        vcs_info+=$hg_revision$phase$not_uptodate
 }



parse_git_status() {

        # TODO add status: LOCKED (.git/index.lock)

        git_dir=`[[ $git_module = "on" ]]  &&  git rev-parse --git-dir 2> /dev/null`
        #git_dir=`eval \$$git_module  git rev-parse --git-dir 2> /dev/null`
        #git_dir=` git rev-parse --git-dir 2> /dev/null`

        [[  -n ${git_dir/./} ]]   ||   return  1

        vcs=git

        ##########################################################   GIT STATUS

        [[ $rawhex_len -gt 0 ]]  && freshness="$dim="

        unset branch status modified added clean init deleted untracked op detached

        if [[ $utf8_prompt ]]; then
            git_up_char="↑"
            git_dn_char="↓"
            git_updn_char="↕"
            git_stash_char="☡";
        else
            git_up_char="^"
            git_dn_char="v"
            git_updn_char="*"
            git_stash_char="$"
        fi


	# info not in porcelain status
        eval " $(
                LANG=C git status 2>/dev/null | sed 's/\\\\/x/g' |
                    sed -n '
                        s/^\(# \)*On branch /branch=/p
                        s/^nothing to commi.*/clean=clean/p
                        s/^\(# \)*Initial commi.*/init=init/p
                        s/^\(# \)*Your branch is ahead of \(.\).\+\2 by [[:digit:]]\+ commit.*/freshness=${WHITE}${git_up_char}/p
                        s/^\(# \)*Your branch is behind \(.\).\+\2 by [[:digit:]]\+ commit.*/freshness=${YELLOW}${git_dn_char}/p
                        s/^\(# \)*Your branch and \(.\).\+\2 have diverged.*/freshness=${YELLOW}${git_updn_char}/p
                    '
        )"

	# porcelain file list
                                        # TODO:  sed-less -- http://tldp.org/LDP/abs/html/arrays.html  -- Example 27-5

                                        # git bug:  (was reported to git@vger.kernel.org )
                                        # echo 1 > "with space"
                                        # git status --porcelain
                                        # ?? with space                   <------------ NO QOUTES
                                        # git add with\ space
                                        # git status --porcelain
                                        # A  "with space"                 <------------- WITH QOUTES

        eval " $(
                LANG=C git status --porcelain 2>/dev/null | sed 's/\\\\/x/g' |
                        sed -n '
                                s,^U. \([^\"][^/]*/\?\).*,         conflicted_files+=(\"\1\"),p
                                s,^U. \"\([^/]\+/\?\).*\"$,        conflicted_files+=(\"\1\"),p
                                s,^.U \([^\"][^/]*/\?\).*,         conflicted_files+=(\"\1\"),p
                                s,^.U \"\([^/]\+/\?\).*\"$,        conflicted_files+=(\"\1\"),p
                                s,^D. \([^\"][^/]*/\?\).*,            deleted_files+=(\"\1\"),p
                                s,^D. \"\([^/]\+/\?\).*\"$,           deleted_files+=(\"\1\"),p
                                s,^.D \([^\"][^/]*/\?\).*,            deleted_files+=(\"\1\"),p
                                s,^.D \"\([^/]\+/\?\).*\"$,           deleted_files+=(\"\1\"),p
                                s,^[MARC]. \([^\"][^/]*/\?\).*,         added_files+=(\"\1\"),p
                                s,^[MARC]. \"\([^/]\+/\?\).*\"$,        added_files+=(\"\1\"),p
                                s,^.[MA] \([^\"][^/]*/\?\).*,        modified_files+=(\"\1\"),p
                                s,^.[MA] \"\([^/]\+/\?\).*\"$,       modified_files+=(\"\1\"),p
                                s,^?? \([^\"][^/]*/\?\).*,          untracked_files+=(\"\1\"),p
                                s,^?? \"\([^/]\+/\?\).*\"$,         untracked_files+=(\"\1\"),p
                        '   # |tee /dev/tty
        )"

          modified=${modified_files[0]:+modified}
             added=${added_files[0]:+added}
           deleted=${deleted_files[0]:+deleted}
         untracked=${untracked_files[0]:+untracked}
        conflicted=${conflicted_files[0]:+conflicted}

        if  ! grep -q "^ref:" "$git_dir/HEAD"  2>/dev/null;   then
                detached=detached
        fi


        #################  GET GIT OP

        unset op

        if [[ -d "$git_dir/.dotest" ]] ;  then

                if [[ -f "$git_dir/.dotest/rebasing" ]] ;  then
                        op="rebase"

                elif [[ -f "$git_dir/.dotest/applying" ]] ; then
                        op="am"

                else
                        op="am/rebase"

                fi

        elif  [[ -f "$git_dir/.dotest-merge/interactive" ]] ;  then
                op="rebase -i"
                # ??? branch="$(cat "$git_dir/.dotest-merge/head-name")"

        elif  [[ -d "$git_dir/.dotest-merge" ]] ;  then
                op="rebase -m"
                # ??? branch="$(cat "$git_dir/.dotest-merge/head-name")"

        # lvv: not always works. Should  ./.dotest  be used instead?
        elif  [[ -f "$git_dir/MERGE_HEAD" ]] ;  then
                op="merge"
                # ??? branch="$(git symbolic-ref HEAD 2>/dev/null)"

        elif  [[ -f "$git_dir/index.lock" ]] ;  then
                op="locked"

        else
                [[  -f "$git_dir/BISECT_LOG"  ]]   &&  op="bisect"
                # ??? branch="$(git symbolic-ref HEAD 2>/dev/null)" || \
                #    branch="$(git describe --exact-match HEAD 2>/dev/null)" || \
                #    branch="$(cut -c1-7 "$git_dir/HEAD")..."
        fi


        ####  GET GIT HEX-REVISION
        if  [[ $rawhex_len -gt 0 ]] ;  then
                rawhex=`git rev-parse HEAD 2>/dev/null`
                rawhex=${rawhex/HEAD/}
                rawhex="$hex_vcs_color${rawhex:0:$rawhex_len}"
        else
                rawhex=""
        fi

        #### branch
        branch=${branch/#master/M}

                        # another method of above:
                        # branch=$(git symbolic-ref -q HEAD || { echo -n "detached:" ; git name-rev --name-only HEAD 2>/dev/null; } )
                        # branch=${branch#refs/heads/}

        ### stash
        local stash_num
        stash_num=$(git stash list 2>/dev/null | wc -l)

        ### compose vcs_info

        if [[ $init ]];  then
                vcs_info=${white}init

        else
                if [[ "$detached" ]] ;  then
                        branch="<detached:`git name-rev --name-only HEAD 2>/dev/null`"


                elif   [[ "$op" ]];  then
                        branch="$op:$branch"
                        if [[ "$op" == "merge" ]] ;  then
                            branch+="<--$(git name-rev --name-only $(<$git_dir/MERGE_HEAD))"
                        fi
                        #branch="<$branch>"
                fi
                vcs_info="$branch$freshness$rawhex"

                if [[ $stash_num -gt 0 ]]; then
                    vcs_info+="${white}$git_stash_char$stash_num"
                fi
        fi
 }


parse_vcs_status() {

        unset   file_list modified_files untracked_files added_files deleted_files conflicted_files
        unset   vcs vcs_info
        unset   status modified untracked added init detached deleted conflicted
        declare -a file_list modified_files untracked_files added_files deleted_files conflicted_files

        [[ $vcs_ignore_dir_list =~ $PWD ]] && return

        eval   $PARSE_VCS_STATUS

        ### status:  choose primary (for branch color)
        unset status
        status=${op:+op}
        status=${status:-$detached}
        status=${status:-$clean}
        status=${status:-$conflicted}
        status=${status:-$modified}
        status=${status:-$added}
        status=${status:-$deleted}
        status=${status:-$untracked}
        status=${status:-$init}
                                # at least one should be set
                                : ${status?prompt internal error: git status}
        eval vcs_color="\${${status}_vcs_color}"
                                # no def:  vcs_color=${vcs_color:-$WHITE}    # default


        ### VIM

        if  [[ $vim_module = "on" ]] ;  then
                # equivalent to vim_glob=`ls .*.vim`  but without running ls
                unset vim_glob vim_file vim_files
                old_nullglob=`shopt -p nullglob`
                    shopt -s nullglob
                    vim_glob=`echo .*.sw?`
                eval $old_nullglob

                if [[ $vim_glob ]];  then
                    set $vim_glob
                    #vim_file=${vim_glob#.}
                    if [[ $# > 1 ]] ; then
                            vim_files="*"
                    else
                            vim_file=${1#.}
                            vim_file=${vim_file/.sw?/}
                            [[ .${vim_file}.swp -nt $vim_file ]]  && vim_files=$vim_file
                    fi
                    # if swap is newer,  then this is unsaved vim session
                    # [temoto custom] if swap is older, then it must be deleted, so show all swaps.
                fi
        fi


        ### file list
        unset file_list
        local excl_mark='!'
        if [[ $count_only = "on" ]] ; then
                [[ ${conflicted_files[0]} ]]  &&  file_list+=" ${conflicted_vcs_color}${excl_mark}${#conflicted_files[@]}"
                [[ ${modified_files[0]}   ]]  &&  file_list+=" "${modified_vcs_color}*${#modified_files[@]}
                [[ ${deleted_files[0]}    ]]  &&  file_list+=" "${deleted_vcs_color}-${#deleted_files[@]}
                [[ ${added_files[0]}      ]]  &&  file_list+=" "${added_vcs_color}+${#added_files[@]}
                [[ ${untracked_files[0]}  ]]  &&  file_list+=" "${untracked_vcs_color}?${#untracked_files[@]}
        else
                [[ ${conflicted_files[0]} ]]  &&  file_list+=" "$conflicted_vcs_color${conflicted_files[@]}
                [[ ${modified_files[0]}   ]]  &&  file_list+=" "$modified_vcs_color${modified_files[@]}
                [[ ${deleted_files[0]}    ]]  &&  file_list+=" "$deleted_vcs_color${deleted_files[@]}
                [[ ${added_files[0]}      ]]  &&  file_list+=" "$added_vcs_color${added_files[@]}
                [[ ${untracked_files[0]}  ]]  &&  file_list+=" "$untracked_vcs_color${untracked_files[@]}

        fi
        [[ ${vim_files}          ]]  &&  file_list+=" "${MAGENTA}vim:${vim_files}

        if [[ $count_only != "on" && ${#file_list} -gt $max_file_list_length ]]  ;  then
                file_list=${file_list:0:$max_file_list_length}
                if [[ $max_file_list_length -gt 0 ]]  ;  then
                        file_list="${file_list% *} $ellipse_marker"
                fi
        fi


        head_local="$vcs_color(${vcs_info}$vcs_color${file_list}$vcs_color)"

        ### fringes
        #head_local="${head_local+$vcs_color$head_local }"
 }

parse_virtualenv_status() {
    local virtualenv

    [[ $virtualenv_module = "on" ]] || return 1

    if [[ -n "$VIRTUAL_ENV" ]] ; then
        virtualenv=`basename $VIRTUAL_ENV`
        virtualenv_string="$virtualenv_color<$virtualenv>"
    else
        virtualenv_string=""
    fi
 }

disable_set_shell_label() {
        trap - DEBUG  >& /dev/null
 }

# show currently executed command in label
enable_set_shell_label() {
        disable_set_shell_label
	# check for BASH_SOURCE being empty, no point running set_shell_label on every line of .bashrc
	# also set up timer here for command_time module
        trap '[[ -z "$BASH_SOURCE" && ($BASH_COMMAND != prompt_command_function) ]] && set_shell_label $BASH_COMMAND; 
	        _gp_timestamp=${_gp_timestamp:-$SECONDS}' DEBUG  >& /dev/null
 }

declare -ft disable_set_shell_label
declare -ft enable_set_shell_label

# autojump (see http://wiki.github.com/joelthelion/autojump)

# TODO reverse the line order of a file
#awk ' { line[NR] = $0 }
#      END  { for (i=NR;i>0;i--)
#             print line[i] }' listlogs

j (){
        : ${1? usage: j dir-beginning}
        # go in ring buffer starting from current index.  cd to first matching dir
        for (( i=(aj_idx-1)%aj_max;   i != aj_idx%aj_max;  i=(--i+aj_max)%aj_max )) ; do
                if [[ ${aj_dir_list[$i]} =~ ^.*/$1[^/]*$ ]] ; then
                        cd "${aj_dir_list[$i]}"
                        return
                fi
        done
        echo '?'
 }

alias jumpstart='echo ${aj_dir_list[@]}'

###################################################################### PROMPT_COMMAND

prompt_command_function() {
        raw_rc="$?"

        if [[ "$rc_module" != "on" || "$raw_rc" == "0" || "$previous_rc" == "$raw_rc" ]]; then
                rc=""
        else
                rc="$rc_color$raw_rc$colors_reset$bell"
        fi
        previous_rc="$raw_rc"

        local slash='/'
        cwd=${PWD/$HOME/\~}                           # substitute  "~"
        cwd="${cwd##[/~]*/}/"                         # default label - path last dir
        set_shell_label "${cwd/$slash$slash/$slash}"  # remove // if root dir

        parse_virtualenv_status
        parse_vcs_status

        if [[ $battery_module == "on" ]]; then
             create_battery_indicator
        else
             battery_indicator=":"
        fi

        if [[ $make_module == "on" ]]; then
             check_make_status
        else
             make_indicator=""
        fi

        if [[ $jobs_module == "on" ]]; then
             create_jobs_indicator
        else
             jobs_indicator=""
        fi

        if [[ $command_time_module == "on" ]]; then
             meas_command_time
        else
             command_time=""
        fi

        if [[ $load_module == "on" ]]; then
             create_load_indicator
        else
             load_indicator=""
        fi

        if [[ $clock_module == "on" ]]; then
             create_clock
        else
             clock_indicator=""
        fi

        if [[ $sudo_module == "on" ]]; then
             create_sudo_marker
        else
             sudo_marker=""
        fi

        # autojump
        if [[ ${aj_dir_list[aj_idx%aj_max]} != $PWD ]] ; then
              aj_dir_list[++aj_idx%aj_max]="$PWD"
        fi

        # if cwd_cmd have back-slash, then assign it value to cwd
        # else eval cwd_cmd,  cwd should have path after exection
        eval "${cwd_cmd/\\/cwd=\\\\}"

        if [[ -w "$PWD" ]]; then
            cwd="${cwd//$slash/$slash_color$slash$dir_color}"
        else
            cwd="${cwd//$slash/$slash_color_readonly$slash$dir_color}"
        fi

        # in effect, echo collapses spaces inside the string and removes them from the start/end
        local prompt_command_string_l
        prompt_command_string_l=$(eval echo $prompt_command_string)
        prompt_command_string_l="PS1=\"\$colors_reset$prompt_command_string_l$prompt_color$prompt_char \$colors_reset\""
        eval $prompt_command_string_l

        # old static string with default order left here for reference
        ###PS1="$colors_reset$rc$virtualenv_string$head_local$color_who_where$colors_reset$jobs_indicator$battery_indicator$dir_color$cwd$make_indicator$prompt_color$prompt_char $colors_reset"

        unset head_local raw_rc jobs_indicator virtualenv_string make_indicator battery_indicator command_time load_indicator clock_indicator sudo_marker
 }

# provide functions to turn the fancy prompt functions on and off
# off: return to old (distro default) prompt
# OFF: plain $
# idea taken from liquidprompt: https://github.com/nojhan/liquidprompt
prompt_on() {
        if [[ -z $GIT_PROMPT_ON ]]; then
            OLD_PS1="$PS1"
            OLD_PROMPT_COMMAND="$PROMPT_COMMAND"
        fi

        PROMPT_COMMAND=prompt_command_function

        enable_set_shell_label

        GIT_PROMPT_ON=1
}

prompt_off() {
        PROMPT_COMMAND="$OLD_PROMPT_COMMAND"
        PS1="$OLD_PS1"

        disable_set_shell_label
}

prompt_OFF() {
        PROMPT_COMMAND="$OLD_PROMPT_COMMAND"
        PS1="\$ "

        disable_set_shell_label
}

prompt_disable_utf8() {
        enable_utf8="off"
        _gp_check_utf8
        _gp_get_id
        _gp_get_tty
        _gp_get_host
        _gp_set_who_where
}

prompt_enable_utf8() {
        enable_utf8="on"
        _gp_check_utf8
        _gp_get_id
        _gp_get_tty
        _gp_get_host
        _gp_set_who_where
}


        prompt_on

        unset rc id _gp_tty modified_files file_list

# vim: set ft=sh ts=8 sw=8 et:
