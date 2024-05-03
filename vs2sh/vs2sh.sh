#!/bin/env sh

#    vs2sh.sh - creates init files for sh-like shells to set environment
#    that allows to work with Visual Studio command line tools
#
#    Copyright (C) 2024 Kirill Makurin
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

#	We're using sed and other text tools, so set locale to C to avoid problems

export LC_ALL=C

tab='	'
nl='
'

IFS="${tab}${nl}"

#	Writes a message to stderr and exits with 1
#
#	$1:	message to write
#
_die() {
	printf '%s: ERROR: %s\n' "$0" "$1" >>/dev/stderr
	exit 1
}

#	Writes message to stdout
#
#	$1:	message to write
#
_msg() {
	printf '%s: %s\n' "$0" "$1"
}

#	Sends text to stdout without trailing newline
#
#	$1:	text
#
_echo() {
	printf '%s' "$1"
}

#	In order to store variable names and their values we will use variables
#	that contain newline-separated lists
#
#	In order to manipulate those lists we will use sed

#	Run sed and print result to stdout
#
#	$1:	sed options (like -n, use '' if none)
#	$2:	sed sctipt to run
#	$3:	text to run sed on
#
#	NOTE: since IFS is set to TAB and NEWLINE, multiple options must be
#	separated using nl or tab variables set earlier in this script. Using
#	single option is the best approach
#
_sed() {
	_echo "$3" | sed $1 "$2"
}

#	Run grep and print result to stdout
#
#	$1:	grep options (like -E, use '' if none)
#	$2:	regex for grep
#	$3:	input to grep
#
#	NOTE: since IFS is set to TAB and NEWLINE, multiple options must be
#	separated using nl or tab variables set earlier in this script. Using
#	single option is the best approach
#
_grep() {
	_echo "$3" | grep $1 "$2"
}

#	sed script to escape all \ characters in a windows path. In addition
#	it also escapes the . characters
#
__sed_quote_winpath='s/\\/\\\\/g ; s/\./\\\./g'

#	Quotes characters that are special to sed in a windows path
#
#	$1:	windows path to quote
#
_quote_winpath() {
	_sed '' "${__sed_quote_winpath}" "$1"
}

#	sed script to escape all \ characters in a unix path. In addition
#	it also escapes the . characters
#
__sed_quote_path='s/\//\\\//g ; s/\./\\\./g'

#	Quotes characters that are special to sed in a unix path
#
#	$1:	unix path to quote
#
_quote_path() {
	_sed '' "${__sed_quote_path}" "$1"
}

#	Convertion of paths between windows and unix formats
#
#	If available, use cygpath. Cygwin, mingw and Git for Windows should have
#	it by default, Msys2 provides it as an additional package
#
#	Otherwise, use sed. Those scripts used to convert paths containing the
#	drive latter, for example:
#		_win_to_unix:	C:\Some\Dir -> /c/Some/Dir
#		_unix_to_win:	/c/some/dir -> C:\some\dir
#
#	They won't resolve paths like /usr/bin. We don't need this anyway

if type cygpath >/dev/null 2>&1; then
	__has_cygpath=yes

	_win_to_unix() {
		cygpath -u "$1"
	}

	_unix_to_win() {
		cygpath -w "$1"
	}
else
	__sed_win_to_unix='/^[a-zA-Z]:\\/bs ; b ; :s { s/^[a-zA-Z]/\/\L&\E/ ; s/:\\/\// ; s/\\/\//g }'

	_win_to_unix() {
		_sed '' "${__sed_unix_to_win}" "$1"
	}

	__sed_unix_to_win='/^\/[a-zA-Z]\//bs ; b ; :s { s/\/[a-zA-Z]\//#&#/ ; s/#\/// ; s/\/#/:\\/ ; s/^./\U&\E/ ; s/\//\\/g }'

	_unix_to_win() {
		_sed '' "${__sed_unix_to_win}" "$1"
	}
fi

if {
	type tac >/dev/null 2>&1
	test $? != 0
}; then
	__sed_tac_get='$p'
	__sed_tac_rem='$d'

	tac() {
		local __value=$(cat)

		while test "x${__value}" != x; do
			_sed -n "${__sed_tac_get}" "${__value}"
			printf '\n'
			__value=$(_sed '' "${__sed_tac_rem}" "${__value}")
		done
	}
fi

if (
	_v1=1
	_v2=2
	_v1+=${_v2}
	test "x${_v1}" = x12
) >/dev/null 2>&1; then
	_append() {
		eval "$1+=\$$2\${nl}"
	}
else
	_append() {
		eval "$1=\"\$$1\$$2\"\${nl}"
	}
fi

#	Get a variable's value form a newline-separated list
#
#	$1:	name of variable to search for
#	$2:	name of variable where to search specified variable
#
_get_value() {
	eval "_sed -n '/^${1}=/s/.*=// ; tp ; b ; :p ; p ; q' \"\$$2\""
}

#	Removes a line from a list
#
#	$1:	value to remove
#	$2:	name of variable holding the list
#
#	the value of $1 must exactly match a line in order to be removed
#
#	If need to remove a directory form a list, consider calling a _quote_*path
#	function defined above before passing the value
#
_remove_value() {
	eval "$2=\$(_sed '' '/^$1$/d' \"\$$2\")"
}

#	Removes a line corresponding to variable specified by $1
#
#	$1:	name of variable to remove
#	$2:	name of variable holding the list
#
_remove_var() {
	eval "$2=\$(_sed '' '/^$1=/d' \"\$$2\")"
}

#	Moves line corresponding to variable $1 from list $2 to list $3
#
#	$1:	name of variable to move
#	$2:	name of variable holding the list where to find $1
#	$3:	name of variable holding the list where to append $1
#
_move_var() {
	local __var_value __line

	__var_value=$(_get_value $1 $2)
	_remove_var $1 $2

	__line="$1=${__var_value}"
	_append $3 __line
}

#	Moves value $1 from list $2 to list $3
#
#	$1:	value to move
#	$2:	name of variable holding the list where to find $1
#	$3:	name of variable holding the list where to append $1
#
_move_value() {
	local __value=$1

	_remove_value "${__value}" $2
	_append $3 __value
}

#	Update value of a variable in the list containing already quoted values
#
#	$1:	name of variable
#	$2:	new value
#	$3:	list where to update its value
#
_update_quoted() {
	local __quoted_value=$(_quote_winpath "$(_quote_winpath "${2}")")

	local __sed_second_quote
	__sed_second_quote="/^$1=.*$/!b ; s/=.*/=${__quoted_value}/"

	eval "$3=\$(_sed '' \"\${__sed_second_quote}\" \"\${$3}\")"
}

#	This functions checks user variable $2, *verifies* that it holds acceptable
#	value and assigns it to variable $1
#
#	If user variable $2 is not set, or set to invalid value, get value of
#	variable $4 form list $5. If it is not present, exit with error message $6
#
#	If $7 is given, instead of exiting, execute command resulting from expansion
#	of $7
#
#	$1:	name of variable where to store result
#	$2:	user variable to check and set $1 to its value if it is set
#	$3:	wildcatd(s) for case statement to verify that value of
#		variable specified by $2 is valid
#	$4:	if variable named by $2 is not set, or contains invalid value,
#		 specify name of variable to retrieve from list %5
#	$5:	list containing variable $5
#	$6:	error message to print if $4 is not found in $5
#
_check_var() {
	if eval "test \"x$2\" = x || test \"x\${$2}\" = x || {
		case \$$2 in
		$3)
			$1=\$$2
			false
			;;
		*)
			true
			;;
		esac
	}"; then
		if test -n "$4" && test -n "$5"; then
			eval "$1=\$(_get_value $4 $5)"
		fi
	fi

	if eval "test \"x\${$1:+set}\" = x"; then
		if test "x$7" = x; then
			_die "$6"
		else
			$7
		fi
	fi
}

#	This function is used to determine VC Redist version, if it is not set
#	by the user
#
_get_redist_version() {
	local __value=$(_get_value VCToolsRedistDir _dev_contents)
	local __sed_get_version='s/\\$// ; s/.*\\//g'

	__redist_version=$(_sed '' "${__sed_get_version}" "${__value}")
}

#	Quotes all values in the list $2 and append their qouted values to list $3
#
#	$1:	name of variable containing names of variables to quote in list $2
#	$2:	name of variable containing values to quote
#	$3:	name of variable where to store quoted values
#
_quotelist() {
	local __line

	eval "for _var in \${$1}; do
		__line=\"\${_var}=\$(_quote_winpath \"\$(_get_value \${_var} $2)\")\"
		_append $3 __line
	done"
}

#	Attempt variable substituion on text $1
#
#	$1:	text on which to try substitutions
#	$2:	list containing values of variables to substitute
#	$3:	list containing quoted values (specify '' if none)
#	$*:	names of variables to try substitute into text of $1
#
_varsubst() {
	local __value=$1
	shift
	local __list=$1
	shift
	local __quoted_list=$1
	shift

	local __var __var_value __sed_script

	for __var in "${@}"; do

		#	Since we may need to loop over same list many times, we may
		#	reduce time required to quote __var's value
		#	by providing list that contains it alrady quoted

		if test "x${__quoted_list}" = x; then
			__var_value=$(_get_value ${__var} ${__list})
			__var_value=$(_quote_winpath "${__var_value}")
		else
			__var_value=$(_get_value ${__var} ${__quoted_list})
		fi

		__sed_script="s/${__var_value}/\$\{${__var}\}/"
		__value=$(_sed '' "${__sed_script}" "${__value}")
	done

	printf '%s' "${__value}"
}

#	Attempt variable substituion on a list
#
#	$1:	list on which to try substitutions
#	$2:	list containing values of variables to substitute
#	$3:	list containing quoted values (specify '' if none)
#	$4:	list entries separator (expected ; or :), must not be special to sed
#	$*:	names of variables to try substitute into text of $1
#
_varsubst_list() {
	local __value=$1
	shift
	local __list=$1
	shift
	local __quoted_list=$1
	shift
	local __separator=$1
	shift

	__value=$(_sed '' "s/\\${__separator}/\\n/g" "${__value}")

	local __var __var_value __sed_script __result

	for __var in "${@}"; do

		#	Since we may need to loop over same list many times, we may
		#	reduce time required to quote __var's value
		#	by providing list that contains it alrady quoted

		if test "x${__quoted_list}" = x; then
			__var_value=$(_get_value ${__var} ${__list})
			__var_value=$(_quote_winpath "${__var_value}")
		else
			__var_value=$(_get_value ${__var} ${__quoted_list})
		fi

		__sed_script="s/${__var_value}/\$\{${__var}\}/"
		__value=$(_sed '' "${__sed_script}" "${__value}")
	done

	for __var in ${__value}; do
		__result="${__result}${__result+${__separator}}${__var}"
	done

	printf '%s' "${__result}"
}

#	Write variable(s) to profile file(s)
#
#	$1:	list of files where to write vales of variables
#	$2:	name of variable containing required line
#	$*:	names of variables to write
#
_writevar() {
	local __files=$1
	shift
	local __subst_src=$1
	shift

	local __var __var_value __file __format

	for __var in "${@}"; do
		__var_value=$(_get_value ${__var} ${__subst_src})
		if test "x${__var_value}" != x; then
			case $__var_value in
			*\$\{*\}*)
				__format='export %s="%s"\n'

				__sed='s/\\/\\\\/g'
				__var_value=$(_sed '' "${__sed}" "${__var_value}")
				;;
			*)
				__format="export %s='%s'\n"
				;;
			esac

			for __file in ${__files}; do
				printf "${__format}" "${__var}" "${__var_value}" >>"${__file}"
			done
		fi
	done
}

#	Write PATH-like variable(s) to profile file(s)
#
#	$1:	list of files where to write vales of variables
#	$2:	name of variable containing required line
#	$*:	names of variables to write
#
_writevar_special() {
	local __files=$1
	shift
	local __subst_src=$1
	shift

	for _var in "${@}"; do

		__value=$(_get_value ${_var} ${__subst_src})

		__sed_split_list='s/;/\n/g'
		__value=$(_sed '' "${__sed_split_list}" "${__value}")

		for _file in ${__files}; do
			printf 'export %s\n' "${_var}" >>"${_file}"

			for _line in ${__value}; do
				__line="\"\${${_var}}\${${_var}+;}${_line}\""
				printf '%s\n' "${_var}=$(_quote_winpath "${__line}")" >>"${_file}"
			done
		done
	done
}

#	Write PATH variable to profile file(s)
#
#	$1:	list of files where to write vales of variables
#	$2:	name of variable containing required line
#	$*:	names of variables to write
#
_writevar_PATH() {
	local __files=$1
	shift
	eval "local __value=\${$1}"
	shift

	local _line __line

	__value=$(printf '%s\n' "${__value}" | tac)

	for _line in ${__value}; do
		if test "x${__has_cygpath}" = xyes; then
			_line=$(_sed '' 's/\\/\\&/' "${_line}")
			__line="\$(cygpath -u \"${_line}\"):\${PATH}"
		elif test "x$(_grep '' '^[a-zA-Z]:\\' "${_line}")" != x; then
			__line="$(_win_to_unix "${_line}"):\${PATH}"
		else
			__line="${_line}:\${PATH}"
		fi

		for _file in ${__files}; do
			printf 'PATH="%s"\n' "${__line}" >>"${_file}"
		done
	done
}

################################################################################

# beginning of execution

_dev_env_file=$1  # file containing development environment
_user_env_file=$2 # file containing standard environment

if test "x${_dev_env_file}" = x; then
	_die "argument 1: is missing - development environment file"
elif test ! -f "${_dev_env_file}"; then
	_die "argument 1: file '${_dev_env_file}' does not exist"
fi

if test "x${_user_env_file}" = x; then
	_die "argument 2: is missing - user environment file"
elif test ! -f "${_user_env_file}"; then
	_die "argument 2: file '${_user_env_file}' does not exist"
fi

_vs_vc=vs_vc.sh      #	output file for Visual C profile
_vs_dotnet=vs_net.sh #	output file for .NET profile
_vs_combined=vs.sh   #	output file for both Visual C and .NET

rm -f "${_vs_vc}" "${_vs_dotnet}" "${_vs_combined}"

_msg 'Reading environment files...'

#	Contents of each environment

_dev_env_contents=
_user_env_contents=

#	List of variables in each environment, same as _*_env_contents, but without
#	value. Just names of variables

_dev_env_vars=
_user_env_vars=

#	List of directories in PATH of each environment

_dev_env_PATH=
_user_env_PATH=

#	Lists of variables/directories exclusive to development environment

_dev_contents=
_dev_vars=
_dev_PATH=

#	Redirected output from PowerShell is UTF-16 encoded, make it UTF-8
#
#	But if it is redirected from cmd it will be (as it seems) UTF-8 encoded,
#	and converting it with 'iconv -f utf-16 -t utf-8' will screw it up
#
#	We'll try to convert form both UTF-8 and UTF-16, and the one
#	that contains line matching '^PATH=' will be used

__grep_path='^PATH='

for __enc in utf-16 utf-8; do
	_dev_env_contents=$(iconv -f "${__enc}" -t utf-8 "${_dev_env_file}" 2>/dev/null)
	if test -n "$(_grep '' "${__grep_path}" "${_dev_env_contents}")"; then
		_dev_env_contents=$(_sed '' 's/\r$//' "${_dev_env_contents}")
		break
	fi
done

for __enc in utf-16 utf-8; do
	_user_env_contents=$(iconv -f "${__enc}" -t utf-8 "${_user_env_file}" 2>/dev/null)
	if test -n "$(_grep '' "${__grep_path}" "${_user_env_contents}")"; then
		_user_env_contents=$(_sed '' 's/\r$//' "${_user_env_contents}")
		break
	fi
done

unset __enc

#	Getting list of variables in each environment and removing all
#	variables whose nome is not a valid shell identifier

__sed_valid_vars='/^[a-zA-Z_][a-zA-Z0-9_]*=/!d ; s/=.*//'

_dev_env_vars=$(_sed '' "${__sed_valid_vars}" "${_dev_env_contents}")
_user_env_vars=$(_sed '' "${__sed_valid_vars}" "${_user_env_contents}")

#	Lopping over both lists and finding variables that are appearing only in
#	the development environment

_msg 'Getting variable appearing only in the development environment...'

for __dev_var in $_dev_env_vars; do
	for __user_var in $_user_env_vars; do
		test "${__dev_var}" = "${__user_var}" && continue 2
	done
	_append _dev_vars __dev_var
done

unset __dev_var __user_var

#	Getting list of each directory in PATH for each environment and replacing
#	each : separator with a newline

_msg 'Comparing PATH variable in both environments...'

__sed_split_path='/^PATH=/s/^PATH=// ; tp ; b ; :p { s/:/\n/g ; p ; q }'

_dev_env_PATH=$(_sed -n "${__sed_split_path}" "${_dev_env_contents}")
_user_env_PATH=$(_sed -n "${__sed_split_path}" "${_user_env_contents}")

#	Getting direcrories that appear only in PATH variable form the development
#	environment

for __dev_dir in ${_dev_env_PATH}; do
	for __user_dir in ${_user_env_PATH}; do
		test "${__dev_dir}" = "${__user_dir}" && continue 2
	done
	_append _dev_PATH __dev_dir
done

unset __dev_dir __user_dir

#	Marking lines containing development environment only variables with
#	the # character at the beginning of the line and then removing those lines

_msg 'Getting values of variables appearing only in the development environment...'

for _var in ${_dev_vars}; do
	__sed_mark_dev_var="/^${_var}=/s/^/#/"

	_dev_env_contents=$(_sed '' "${__sed_mark_dev_var}" "${_dev_env_contents}")
done

unset __sed_mark_dev_var

__sed_strip_marked_lines='/^#/!d ; s/^#//'

_dev_contents=$(_sed '' "${__sed_strip_marked_lines}" "${_dev_env_contents}")

# Checking for required variables that must be set

__vsinstalldir=
__host=
__target=
__ucrt_version=
__tools_version=
__redist_version=

_msg 'Getting required environment information...'

_check_var \
	__vsinstalldir \
	'' \
	'*' \
	VSINSTALLDIR \
	_dev_contents \
	"cannot determine Visual Studio installation directory"

_check_var \
	__host \
	VS_HOST \
	'x64 | x86' \
	VSCMD_ARG_HOST_ARCH \
	_dev_contents \
	"cannot determine host"

_check_var \
	__target \
	VS_TARGET \
	'x64 | x86 | arm64 | arm' \
	VSCMD_ARG_TGT_ARCH \
	_dev_contents \
	"cannot determine target"

_check_var \
	__ucrt_version \
	VS_UCRT_SDK_VERSION \
	'*.*.*.*' \
	UCRTVersion \
	_dev_contents \
	"cannot determine UCRT version"

_check_var \
	__tools_version \
	VS_TOOLS_VERSION \
	'*.*.*' \
	VCToolsVersion \
	_dev_contents \
	"cannot determine VC tools version"

_check_var \
	__redist_version \
	VS_REDIST_VERSION \
	'*.*.*.*' \
	'' \
	'' \
	'' \
	_get_redist_version

_msg "Visual Studio: ${__vsinstalldir}"
_msg "HOST: ${__host}"
_msg "TARGET: ${__target}"
_msg "UCRT SDK version: ${__ucrt_version}"
_msg "VC Tools version: ${__tools_version}"
_msg "VC Redist version: ${__redist_version}"

#	Remove some known not needed variables

for _var in ${_dev_vars}; do
	case ${_var} in
	__*)
		_remove_var "${_var}" _dev_contents
		_remove_value "${_var}" _dev_vars
		;;
	esac
done

#	We want to store variables in memory to perform variable subtitutions later,
#	however, we'll write and remove some variable immediately

#	Values of following variables will be written immediately and they
#	will be unset and won't be used in varaible substitutions

_no_store_vars=
_no_store_contents=

#	Value of _common_* variables will go into each profile file after
#	_no_store_* variables,

_common_vars=

#	The _common_special_vars is an exception, it contains variables that
#	required for both profiles, but some values make sence only for certain one
#	It goes after _vc_* and _dotnet_* variables

_common_special_vars=

_common_contents=

#	All _*_PATH variables go to the very end of profile files

_common_PATH=

#	Value of following variables will go into corresponding profile and
#	into combined peofile file after _common_* variables

_vc_vars=

#	Following two variables similar in that they contain ;-separated lists,
#	however, they will be written in different ways in the profile files

_vc_PATH_like=
_vc_special_vars=

_vc_contents=
_vc_PATH=

_dotnet_vars=

_dotnet_contents=
_dotnet_PATH=

#	Following variables are to store variables that have been alradry added to
#	_*_contents and may be used in variable substitution

__common_vars=
__vc_vars=
__dotnet_vars=

#	Following variables are to store qouted values from _*_contents

__common_contents=
__vc_contents=
__dotnet_contents=

#	Following variable are to store contents of _*_PATH variables, but with
#	paths converted from unix to windows format, so we may attempt
#	variable substitutions on them if cygpath is found on system

__common_PATH=
__vc_PATH=
__dotnet_PATH=

#	Value of following variables will go into each profile file after
#	all _vc_* and _dotnet_* variables

_other_vars=
_other_contents=

#	Splitting directories in PATH

_msg 'Splitting PATH entries according to profile they belong to...'

#	We do not use _move_value because it should be quoted when passed to
#	_remove_value, but should not be quoted when passed to _append

for _dir in ${_dev_PATH}; do
	case $_dir in
	*VC* | *[Ll][Ll][Vv][Mm]* | *[Cc][Mm][Aa][Kk][Ee]* | *'Windows Kits'*)
		_append _vc_PATH _dir
		;;
	*NET* | *[Ff]ramework* | *[Rr]oslyn*)
		_append _dotnet_PATH _dir
		;;
	*)
		_append _common_PATH _dir
		;;
	esac
	_remove_value "$(_quote_path "${_dir}")" _dev_PATH
done

unset _dev_PATH

#	Splitting variables

_msg 'Splitting variables according to profile they belong to...'

#	We want some variables to be in specific order in the profile files

for _var in VisualStudioVersion VSINSTALLDIR DevEnvDir; do
	__value=$(_get_value ${_var} _dev_contents)
	if test "x${__value}" != x; then
		_move_value "${_var}" _dev_vars _common_vars
	fi
done

for _var in UCRTVersion \
	VCToolsVersion \
	VCINSTALLDIR \
	VCToolsInstallDir \
	VCToolsRedistDir \
	VCIDEInstallDir \
	UniversalCRTSdkDir \
	WindowsSDKVersion \
	WindowsSDKLibVersion \
	WindowsSdkDir; do
	__value=$(_get_value ${_var} _dev_contents)
	if test "x${__value}" != x; then
		_move_value "${_var}" _dev_vars _vc_vars
	fi
done

#	Splitiing variables according to the profile they must go to

for _var in ${_dev_vars}; do
	case ${_var} in
	LIBPATH)
		_move_value "${_var}" _dev_vars _common_special_vars
		;;
	VSCMD* | is_x64_arch | CommandPromptType | Platform | PreferredToolArchitecture)
		_move_value "${_var}" _dev_vars _no_store_vars
		_move_var "${_var}" _dev_contents _no_store_contents
		;;
	*[Ff]ramework* | FSHARP)
		_move_value "${_var}" _dev_vars _dotnet_vars
		;;
	*INCLUDE* | LIB)
		_move_value "${_var}" _dev_vars _vc_special_vars
		;;
	Windows*Path)
		_move_value "${_var}" _dev_vars _vc_PATH_like
		;;
	Windows[Ss][Dd][Kk]* | ExtensionSdkDir | VC* | *CRT*)
		_move_value "${_var}" _dev_vars _vc_vars
		;;
	VS* | *[Vv]isual[Ss]tudio*)
		_move_value "${_var}" _dev_vars _common_vars
		;;
	*)
		_move_value "${_var}" _dev_vars _other_vars
		_move_var "${_var}" _dev_contents _other_contents
		;;
	esac
done

#	Writing _no_store_* variables into each profile file

_msg 'Writing some common variables without variable substitutions...'

_writevar \
	"${_vs_vc}${nl}${_vs_dotnet}${nl}${_vs_combined}" \
	_no_store_contents \
	${_no_store_vars}

unset _no_store_contents _no_store_vars

#

_msg 'Performing variable substitutions on common variables...'

_quotelist _common_vars _dev_contents __common_contents

for _var in ${_common_vars}; do
	__value=$(_get_value ${_var} _dev_contents)

	__new_value=$(_varsubst "${__value}" _dev_contents __common_contents ${__common_vars})

	if test "${__value}" != "${__new_value}"; then
		_update_quoted ${_var} "${__new_value}" __common_contents

		__value=${__new_value}
	fi

	__line="${_var}=${__value}"

	_append _common_contents __line
	_append __common_vars _var
done

#

_msg 'Performing variable substitutions on VC variables...'

_quotelist _vc_vars _dev_contents __vc_contents

for _var in ${_vc_vars}; do
	__value=$(_get_value ${_var} _dev_contents)

	case ${_var} in
	VCToolsRedistDir)
		__value=$(_sed '' 's/[0-9]\+\.[0-9]\+\.[0-9]\+/########/' "${__value}")
		;;
	esac

	__new_value=$(_varsubst "${__value}" _dev_contents __common_contents ${__common_vars})
	__new_value=$(_varsubst "${__new_value}" _dev_contents __vc_contents ${__vc_vars})

	if test "${__value}" != "${__new_value}"; then
		_update_quoted ${_var} "${__new_value}" __vc_contents

		__value=${__new_value}
	fi

	case ${_var} in
	VCToolsRedistDir)
		__value=$(_sed '' "s/########/$(_quote_winpath "${__redist_version}")/" ${__value})
		;;
	esac

	__line="${_var}=${__value}"

	_append _vc_contents __line
	_append __vc_vars _var
done

for _var in ${_vc_PATH_like} ${_vc_special_vars}; do
	__value=$(_get_value ${_var} _dev_contents)

	__value=$(_varsubst_list "${__value}" _dev_contents __common_contents ';' ${__common_vars})
	__value=$(_varsubst_list "${__value}" _dev_contents __vc_contents ';' ${__vc_vars})

	__line="${_var}=${__value}"

	_append _vc_contents __line
done

#

_msg 'Performing variable substitutions on .NET variables...'

_quotelist _dotnet_vars _dev_contents __dotnet_contents

for _var in ${_dotnet_vars}; do
	__value=$(_get_value ${_var} _dev_contents)

	__new_value=$(_varsubst "${__value}" _dev_contents __common_contents ${__common_vars})
	__new_value=$(_varsubst "${__new_value}" _dev_contents __dotnet_contents ${__dotnet_vars})

	if test "${__value}" != "${__new_value}"; then
		_update_quoted ${_var} "${__new_value}" __dotnet_contents

		__value=${__new_value}
	fi

	__line="${_var}=${__value}"

	_append _dotnet_contents __line
	_append __dotnet_vars _var
done

#

_msg 'Performing variable substitutions on special variables...'

for _var in ${_common_special_vars}; do
	__value=$(_get_value ${_var} _dev_contents)
	__list=$(_sed '' 's/;/\n/g' "${__value}")

	__vc_items=
	__dotnet_items=
	__common_items=

	for __item in ${__list}; do
		case ${__item} in
		*NET* | *[Ff]ramework*)
			__dotnet_items="${__dotnet_items}${__dotnet_items+;}${__item}"
			;;
		*MSVC* | *VC* | *'Windows Kits'*)
			__vc_items="${__vc_items}${__vc_items+;}${__item}"
			;;
		*)
			__common_items="${__common_items}${__common_items+;}${__item}"
			;;
		esac
	done

	if test "x${__common_items}" != x; then
		__common_items=$(_varsubst_list "${__common_items}" _dev_contents __common_contents ';' ${__common_vars})

		__line="${_var}=${__common_items}"

		_append _common_contents __line
	fi

	if test "x${__vc_items}" != x; then
		__vc_items=$(_varsubst_list "${__vc_items}" _dev_contents __common_contents ';' ${__common_vars})
		__vc_items=$(_varsubst_list "${__vc_items}" _dev_contents __vc_contents ';' ${__vc_vars})

		__line="${_var}=${__vc_items}"

		_append _vc_contents __line
	fi

	if test "x${__dotnet_items}" != x; then
		__dotnet_items=$(_varsubst_list "${__dotnet_items}" _dev_contents __common_contents ';' ${__common_vars})
		__dotnet_items=$(_varsubst_list "${__dotnet_items}" _dev_contents __dotnet_contents ';' ${__dotnet_vars})

		__line="${_var}=${__dotnet_items}"

		_append _dotnet_contents __line
	fi
done

#

if test "x${__has_cygpath}" = xyes; then

	_msg 'Performing variable substitutions on PATH directories...'

	for _dir in ${_common_PATH}; do
		__line=$(_unix_to_win "${_dir}")

		_append __common_PATH __line
	done

	__common_PATH=$(_varsubst_list "${__common_PATH}" _dev_contents __common_contents "${nl}" ${__common_vars})

	for _dir in ${_vc_PATH}; do
		__line=$(_unix_to_win "${_dir}")

		_append __vc_PATH __line
	done

	__vc_PATH=$(_varsubst_list "${__vc_PATH}" _dev_contents __common_contents "${nl}" ${__common_vars})
	__vc_PATH=$(_varsubst_list "${__vc_PATH}" _dev_contents __vc_contents "${nl}" ${__vc_vars})

	for _dir in ${_dotnet_PATH}; do
		__line=$(_unix_to_win "${_dir}")

		_append __dotnet_PATH __line
	done

	__dotnet_PATH=$(_varsubst_list "${__dotnet_PATH}" _dev_contents __common_contents "${nl}" ${__common_vars})
	__dotnet_PATH=$(_varsubst_list "${__dotnet_PATH}" _dev_contents __dotnet_contents "${nl}" ${__dotnet_vars})
fi

#	Finally writing profile files

_msg 'Writing profiles...'

_writevar "${_vs_combined}${nl}${_vs_vc}${nl}${_vs_dotnet}" _common_contents ${_common_vars}

_writevar "${_vs_combined}${nl}${_vs_vc}" _vc_contents ${_vc_vars} ${_vc_PATH_like}

_writevar_special "${_vs_combined}${nl}${_vs_vc}" _vc_contents ${_vc_special_vars}

_writevar "${_vs_combined}${nl}${_vs_dotnet}" _dotnet_contents ${_dotnet_vars}

#	this will add 'export LIBPATH' twice to the combined profile, but I do not
#	think it is a problem

_writevar_special "${_vs_combined}${nl}${_vs_vc}" _vc_contents ${_common_special_vars}

_writevar_special "${_vs_combined}${nl}${_vs_dotnet}" _dotnet_contents ${_common_special_vars}

_writevar "${_vs_combined}${nl}${_vs_dotnet}" _other_contents ${_other_vars}

if test "x${__has_cygpath}" = xyes; then
	_writevar_PATH "${_vs_combined}${nl}${_vs_vc}${nl}${_vs_dotnet}" __common_PATH
	_writevar_PATH "${_vs_combined}${nl}${_vs_vc}" __vc_PATH
	_writevar_PATH "${_vs_combined}${nl}${_vs_dotnet}" __dotnet_PATH
else
	_writevar_PATH "${_vs_combined}${nl}${_vs_vc}${nl}${_vs_dotnet}" _common_PATH
	_writevar_PATH "${_vs_combined}${nl}${_vs_vc}" _vc_PATH
	_writevar_PATH "${_vs_combined}${nl}${_vs_dotnet}" _dotnet_PATH
fi

#	Finally it is over

_msg 'Done!'

exit 0
