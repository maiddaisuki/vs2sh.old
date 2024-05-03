#    dev_pws_to_bash.sh - stupid profile generator for stupid Visual Studio
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

__resolve_path() {
	local IFS=$'\n'

	local __path="$1"
	local __full_path=
	local __final_path=

	if [[ "$1" == . ]]; then
		__path=$(pwd)/
	elif [[ "$1" != /* ]]; then
		__path=$(pwd)/"$__path"
	fi

	for __part in ${__path//'/'/$'\n'}; do

		case $__part in
		..)
			if [[ "$__full_path" != / ]]; then
				__full_path="${__full_path%/*}"
			fi
			;;
		*)
			__full_path="$__full_path"/"$__part"
			;;
		esac
	done

	for __part in ${__full_path//'/'/$'\n'}; do
		__final_path="$__final_path"/"$__part"
		if [ ! -d "$__final_path" ]; then
			mkdir "$__final_path"
		fi
	done
}

# This function takes 3 arguments:
#
#   __str: value to be written.
#
#   __file: list of files separated by ',' to whom to write value of __str. To write to stdout give '/dev/stdout' as the file name.
#
#   [optional] __modes: list of modes separated by ',' which must be applied to value of __str before writing it.
#
#   modes:
#
#       quoteval:   single quote everything in value of __str after '=' character. Used to qoute paths.
#
#       quotepath:  like quoteval, but single qoutes everything after '=' and before ':'.
#
#       quotepath-like:  like quotepath, but single qoutes everything after '=' and before ';'.
#
#       envbase:    remove trailing part after and including the first '=' in value of __str
#
#       envval:     remove leading part until and including the first '=' in value of __str
#
#       export:     add 'export ' before expansion of the value of __str
#
#   Operations are performed in order they are specified.
#
__write_env_val() {
	local __str="${1}"
	local __files="${2}"
	local __modes="${3}"

	for __mode in ${__modes/,/$'\n'}; do

		case "${__mode}" in
		quoteval)
			__str="${__str/=/=\'}"\'
			;;
		quotepath)
			if [[ "${__str}" == *='$'* ]]; then
				__str="${__str/:/\':}"\'

			else
				__str="${__str/=/=\'}"
				__str="${__str/:/\':}"
			fi
			;;
		quotepath-like)
			if [[ "${__str}" == *='$'* ]]; then
				__str="${__str/;/;\'}"\'

			else
				__str="${__str/=/=\'}"
				__str="${__str/;/;\'}"
			fi
			;;
		envbase)
			__str="${__str%%=*}"
			;;
		envval)
			__str="${__str#*=}"
			;;
		export)
			__str="export ${__str}"
			;;
		esac

	done

	for __file in ${__files//,/$'\n'}; do
		echo "$__str" >>"$__file"
	done
}

# This function searches for the the value of the first argument given in __dev_env array.
#
# If the given environment variable name is found, it is written to given files.
#
# The second and third arguments are the same as in __write_env_val function.
__search_dev_env_and_write() {
	for __var in ${__dev_env[*]}; do
		if [[ "$__var" == "${1}"=* ]]; then
			__write_env_val "$__var" "${2}" "${3}"
		fi
	done
}

dev_pws_to_bash() {
	local IFS=$'\n'

	local __def_env_file=${1:?"Error: Default environment file is not given."}
	local __dev_env_file=${2:?"Error: Development environment file is not given."}

	if [ ! -f "$__def_env_file" ]; then
		echo Error: "$__def_env_file" does not exist.
		return 1
	fi

	if [ ! -f "$__dev_env_file" ]; then
		echo Error: "$__dev_env_file" does not exist.
		return 1
	fi

	local output_prefix=${OUTPUT_PREFIX:-.env_output/}
	__resolve_path "$output_prefix"

	local dump_prefix=${DUMP_PREFIX:-.env_dump/}
	__resolve_path "$dump_prefix"

	local path_file="$dump_prefix"path.list
	local vars_file="$dump_prefix"vars.list
	local full_vars_file="$dump_prefix"variables.list
	local redists_file="$dump_prefix"redists.list
	local sdks_file="$dump_prefix"sdks.list
	local tools_file="$dump_prefix"tools.list

	if test -f $path_file; then rm $path_file; fi
	if test -f $vars_file; then rm $vars_file; fi
	if test -f $full_vars_file; then rm $full_vars_file; fi
	if test -f $redists_file; then rm $redists_file; fi
	if test -f $sdks_file; then rm $sdks_file; fi
	if test -f $tools_file; then rm $tools_file; fi

	local __def_env_vars=
	local __dev_env_vars=

	local __def_env_path=
	local __dev_env_path=

	local __def_env=($(cat "${__def_env_file}"))
	local __dev_env=($(cat "${__dev_env_file}"))

	local __def_env_var_count=0
	local __dev_env_var_count=0

	for variable in ${__def_env[*]}; do
		__var="${variable%%=*}"

		__def_env_vars[${__def_env_var_count}]="$__var"
		let __def_env_var_count++

		if [[ $__var == PATH ]]; then
			__def_env_path="${variable/PATH=/''}"
		fi
	done

	for variable in ${__dev_env[*]}; do
		__var="${variable%%=*}"

		__dev_env_vars[${__dev_env_var_count}]="$__var"
		let __dev_env_var_count++

		if [[ "$__var" == PATH ]]; then
			__dev_env_path="${variable/PATH=/''}"
		fi
	done

	local __dev_env_only_vars=
	local __dev_env_only_path=

	local __dev_env_only_vars_count=0
	local __dev_env_only_path_count=0

	for __dev_var in ${__dev_env_vars[*]}; do
		local __exists=0
		for __def_var in ${__def_env_vars[*]}; do
			if [[ "$__dev_var" == "$__def_var" ]]; then
				__exists=1
			fi
		done

		if ! ((__exists)); then
			__dev_env_only_vars[$__dev_env_only_vars_count]="${__dev_var}"
			let __dev_env_only_vars_count++
		fi
	done

	for __dev_var in ${__dev_env_path//:/$'\n'}; do
		local __exists=0
		for __def_var in ${__def_env_path//:/$'\n'}; do
			if [[ "$__dev_var" == "$__def_var" ]]; then
				__exists=1
			fi
		done

		if ! ((__exists)); then
			__dev_env_only_path[$__dev_env_only_path_count]="${__dev_var}"
			let __dev_env_only_path_count++
		fi
	done

	for var in ${__dev_env_only_vars[*]}; do
		__write_env_val "$var" "$vars_file"
		for _var in ${__dev_env[*]}; do
			if [[ "${var}" == "${_var/=*/}" ]]; then
				__write_env_val "$_var" "$full_vars_file"
			fi
		done
	done

	for var in ${__dev_env_only_path[*]}; do
		__write_env_val "$var" "$path_file"
	done

	local is_host_set=0
	local is_target_set=0
	local is_sdk_set=0
	local is_tools_set=0
	local is_redist_set=0

	local __vars_set=
	local __vars_set_count=

	if [ -n "$HOST" ] &&
		([[ "$HOST" == x86 ]] || [[ "$HOST" == x64 ]]); then
		is_host_set=1
	fi

	if [ -n "$TARGET" ] &&
		([[ "$TARGET" == x86 ]] || [[ "$TARGET" == x64 ]] ||
			[[ "$TARGET" == arm ]] || [[ "$TARGET" == arm64 ]]); then
		is_target_set=1
	fi

	if [ -n "$UCRT_SDK_VERSION" ] &&
		[[ "$UCRT_SDK_VERSION" == [[:digit:]]*.[[:digit:]]*.[[:digit:]]*.*[[:digit:]] ]]; then
		is_sdk_set=1
	fi

	if [ -n "$VC_TOOLS_VERSION" ] &&
		[[ "$VC_TOOLS_VERSION" == [[:digit:]]*.[[:digit:]]*.*[[:digit:]] ]]; then
		is_tools_set=1
	fi

	if [ -n "$VC_REDIST" ] &&
		[[ "$VC_REDIST" == [[:digit:]]*.[[:digit:]]*.*[[:digit:]] ]]; then
		is_redist_set=1
	fi

	if ! ((is_host_set)); then
		HOST=$(__search_dev_env_and_write VSCMD_ARG_HOST_ARCH /dev/stdout envval)
	fi

	if ! ((is_target_set)); then
		TARGET=$(__search_dev_env_and_write VSCMD_ARG_TGT_ARCH /dev/stdout envval)
	fi

	if [ -z "${TARGET}" ] || [ -z "${HOST}" ]; then
		echo "ERROR: TARGET and/or HOST are not set."
		return 1
	fi

	echo HOST: "$HOST"
	echo TARGET: "$TARGET"

	if ! ((is_sdk_set)); then
		UCRT_SDK_VERSION=$(__search_dev_env_and_write UCRTVersion /dev/stdout envval)
	fi

	if ! ((is_tools_set)); then
		VC_TOOLS_VERSION=$(__search_dev_env_and_write VCToolsVersion /dev/stdout envval)
	fi

	if [ -z "${UCRT_SDK_VERSION}" ] || [ -z "${VC_TOOLS_VERSION}" ]; then
		echo "ERROR: UCRTVersion and/or VCToolsVersion variable are not set."
		return 1
	fi

	local __vs_install_dir=$(__search_dev_env_and_write VSINSTALLDIR /dev/stdout envval)

	if [ -z "$__vs_install_dir" ]; then
		echo Error: VSINSTALLDIR is not set.
		return 1
	fi

	echo UCRT_SDK_VERSION: "$UCRT_SDK_VERSION"
	echo VC_TOOLS_VERSION: "$VC_TOOLS_VERSION"
	echo __vs_install_dir: "$__vs_install_dir"

	local script_common="$output_prefix"vs_common.sh
	local script_vc="$output_prefix"vs_vc.sh
	local script_dotnet="$output_prefix"vs_dotnet.sh
	local script_all="$output_prefix"vs_all.sh
	local script_single="$output_prefix"vs_single.sh

	if [ -f $script_common ]; then rm $script_common; fi
	if [ -f $script_all ]; then rm $script_all; fi
	if [ -f $script_single ]; then rm $script_single; fi
	if [ -f $script_vc ]; then rm $script_vc; fi
	if [ -f $script_dotnet ]; then rm $script_dotnet; fi

	local __mode_qoute_and_export=quoteval,export
	local __script_files_to_write="$script_common,$script_single"

	__write_env_val "VSCMD_ARG_HOST_ARCH=$HOST" "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val "VSCMD_ARG_TGT_ARCH=$TARGET" "$__script_files_to_write" "$__mode_qoute_and_export"

	__search_dev_env_and_write 'is_x64_arch' "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write 'PreferredToolArchitecture' "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write 'CommandPromptType' "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val '' "$__script_files_to_write"

	__search_dev_env_and_write 'VisualStudioVersion' "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write 'VSCMD_VER' "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write 'VSCMD_ARG_app_plat' "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val '' "$__script_files_to_write"

	__search_dev_env_and_write 'WSLENV' "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write 'PROMPT' "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val '' "$__script_files_to_write"

	__search_dev_env_and_write "HTMLHelpDir" "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write 'FPS_BROWSER_USER_PROFILE_STRING' "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write 'FPS_BROWSER_APP_PROFILE_STRING' "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val '' "$__script_files_to_write"

	__search_dev_env_and_write "VSINSTALLDIR" "$__script_files_to_write" "$__mode_qoute_and_export"

	__write_env_val 'DevEnvDir="$VSINSTALLDIR"'\''Common7\IDE\'\' "$__script_files_to_write" export
	__write_env_val 'VS170COMNTOOLS="$VSINSTALLDIR"'\''Common7\Tools\'\' "$__script_files_to_write" export
	__write_env_val 'VSSDK150INSTALL="$VSINSTALLDIR"VSSDK' "$__script_files_to_write" export
	__write_env_val 'VSSDKINSTALL="$VSINSTALLDIR"VSSDK' "$__script_files_to_write" export
	__search_dev_env_and_write ExtensionSdkDir "$__script_files_to_write" "$__mode_qoute_and_export"

	__script_files_to_write="$script_all,$script_vc,$script_single"

	__write_env_val ". $script_common" "$script_all,$script_vc"
	__write_env_val '' "$__script_files_to_write"

	__write_env_val UCRTVersion=$UCRT_SDK_VERSION "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val VCToolsVersion=$VC_TOOLS_VERSION "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val '' "$__script_files_to_write"

	__write_env_val 'WindowsSDKLibVersion="$UCRTVersion"'\'\\\' "$__script_files_to_write" export
	__write_env_val 'WindowsSDKVersion="$UCRTVersion"'\'\\\' "$__script_files_to_write" export
	__write_env_val '' "$__script_files_to_write"
	__write_env_val 'VCIDEInstallDir="$VSINSTALLDIR"'\''Common7\IDE\VC\'\' "$__script_files_to_write" export
	__write_env_val 'VCINSTALLDIR="$VSINSTALLDIR"'\''VC\'\' "$__script_files_to_write" export
	__write_env_val 'VCToolsInstallDir="$VSINSTALLDIR"'\''VC\Tools\MSVC\'\''"$VCToolsVersion"'\'\\\' "$__script_files_to_write" export

	if [ -d ${__vs_install_dir}VC/tools/MSVC/ ]; then
		for __dir in $(dir --width=1 ${__vs_install_dir}VC/tools/MSVC/); do
			if [[ $__dir == *.*.* ]]; then
				if [ -d "${__vs_install_dir}VC/tools/MSVC/$__dir/bin" ]; then
					echo $__dir >>$tools_file
				fi
			fi
		done
	fi

	local __last_vc_redist=

	if [ -d ${__vs_install_dir}VC/redist/MSVC/ ]; then
		for __dir in $(dir --width=1 ${__vs_install_dir}VC/redist/MSVC/); do
			if [[ $__dir == *.*.* ]]; then
				echo $__dir >>$redists_file
				__last_vc_redist="$__dir"
			fi
		done
	fi

	if [[ -z "$VC_REDIST" ]]; then
		VC_REDIST="$__last_vc_redist"
	fi

	if [[ -z "$VC_REDIST" ]]; then
		echo WARNING: VC_REDIST variable is not set.
	else
		echo VC_REDIST: "$VC_REDIST"
	fi

	__write_env_val 'VCToolsRedistDir="$VSINSTALLDIR"'\''VC\Redist\MSVC\'"$VC_REDIST\\"\' "$__script_files_to_write" export
	__write_env_val '' "$__script_files_to_write"

	__write_env_val "WindowsSdkDir='C:\Program Files (x86)\Windows Kits\10\'" "$__script_files_to_write" export
	__write_env_val 'UniversalCRTSdkDir="$WindowsSdkDir"' "$__script_files_to_write" export
	__write_env_val 'WindowsSdkBinPath="$WindowsSdkDir"'\''bin\'\' "$__script_files_to_write" export
	__write_env_val 'WindowsSdkVerBinPath="$WindowsSdkBinPath"''"$UCRTVersion"'\''\\'\' "$__script_files_to_write" export
	__write_env_val '' "$__script_files_to_write"

	__write_env_val 'WindowsLibPath="$WindowsSdkDir"'\'UnionMetadata\\\''"$UCRTVersion"'\'';'\' "$__script_files_to_write" export
	__write_env_val 'WindowsLibPath=$WindowsLibPath"$WindowsSdkDir"'\'References\\\''"$UCRTVersion"'\'';'\' "$__script_files_to_write"
	__write_env_val '' "$__script_files_to_write"

	if [ -d 'C:\Program Files (x86)\Windows Kits\10\include' ]; then
		for entry in $(dir --width=1 'C:\Program Files (x86)\Windows Kits\10\include'); do
			if [[ $entry == *.*.*.* ]]; then
				echo $entry >>$sdks_file
			fi
		done
	fi

	if [[ "$TARGET" == x64 ]] || [[ "$TARGET" == x86 ]]; then
		__write_env_val 'IFCPATH="$VSINSTALLDIR"'\''VC\Tools\MSVC\'\''"$VCToolsVersion"'\''\ifc\x64'\' "$__script_files_to_write" export
		__write_env_val '' "$__script_files_to_write"
	fi
	__write_env_val 'INCLUDE="$VCINSTALLDIR"'\''Tools\MSVC\'\''"$VCToolsVersion"'\''\include;'\' "$__script_files_to_write" export
	__write_env_val 'INCLUDE="$INCLUDE""$VCINSTALLDIR"'\''Tools\MSVC\'\''"$VCToolsVersion"'\''\ATLMFC\include;'\' "$__script_files_to_write"
	__write_env_val 'INCLUDE="$INCLUDE""$VCINSTALLDIR"'\''Auxiliary\VS\include;'\' "$__script_files_to_write"
	__write_env_val 'INCLUDE="$INCLUDE""$UniversalCRTSdkDir"'\''include\'\''"$UCRTVersion"'\''\ucrt;'\' "$__script_files_to_write"
	__write_env_val 'INCLUDE="$INCLUDE""$UniversalCRTSdkDir"'\''include\'\''"$UCRTVersion"'\''\um;'\' "$__script_files_to_write"
	__write_env_val 'INCLUDE="$INCLUDE""$UniversalCRTSdkDir"'\''include\'\''"$UCRTVersion"'\''\shared;'\' "$__script_files_to_write"
	__write_env_val 'INCLUDE="$INCLUDE""$UniversalCRTSdkDir"'\''include\'\''"$UCRTVersion"'\''\winrt;'\' "$__script_files_to_write"
	__write_env_val 'INCLUDE="$INCLUDE""$UniversalCRTSdkDir"'\''include\'\''"$UCRTVersion"'\''\cppwinrt;'\' "$__script_files_to_write"
	__write_env_val 'INCLUDE=''"$INCLUDE"'\''C:\Program Files (x86)\Windows Kits\NETFXSDK\4.8\include\um;'\' "$__script_files_to_write"
	__write_env_val '' "$__script_files_to_write"

	__write_env_val 'EXTERNAL_INCLUDE="$INCLUDE"' "$__script_files_to_write" export
	__write_env_val '' "$__script_files_to_write"

	__write_env_val 'LIB="$VCINSTALLDIR"'\''Tools\MSVC\'\''"$VCToolsVersion"'\''\ATLMFC\lib\'\''"$VSCMD_ARG_TGT_ARCH"'\'';'\' "$__script_files_to_write" export
	__write_env_val 'LIB="$LIB"''$VCINSTALLDIR"'\''Tools\MSVC\'\''$VCToolsVersion"'\''\lib\'\''"$VSCMD_ARG_TGT_ARCH"'\'';'\' "$__script_files_to_write"
	if [[ "$TARGET_NAME" != arm64 ]]; then
		__write_env_val 'LIB="$LIB"'\''C:\Program Files (x86)\Windows Kits\NETFXSDK\4.8\lib\um\'\''"$VSCMD_ARG_TGT_ARCH"'\'';'\' "$__script_files_to_write"
	fi
	__write_env_val 'LIB="$LIB"''"$UniversalCRTSdkDir"'\''lib\'\''"$UCRTVersion"'\''\ucrt\'\''"$VSCMD_ARG_TGT_ARCH"'\'';'\' "$__script_files_to_write"
	__write_env_val 'LIB="$LIB"''"$UniversalCRTSdkDir"'\''lib\'\''"$UCRTVersion"'\''\um\'\''"$VSCMD_ARG_TGT_ARCH"'\'';'\' "$__script_files_to_write"

	__write_env_val '' "$__script_files_to_write"
	__write_env_val 'LIBPATH=''"$VCINSTALLDIR"'\''Tools\MSVC\'\''"$VCToolsVersion"'\''\ATLMFC\lib\'\''"$VSCMD_ARG_TGT_ARCH"'\'';'\' "$__script_files_to_write" export
	__write_env_val 'LIBPATH="$LIBPATH""$VCINSTALLDIR"'\''Tools\MSVC\'\''"$VCToolsVersion"'\''\lib\'\''"$VSCMD_ARG_TGT_ARCH"'\'';'\' "$__script_files_to_write"
	__write_env_val 'LIBPATH="$LIBPATH""$VCINSTALLDIR"'\''Tools\MSVC\'\''"$VCToolsVersion"'\''\lib\x86\store\references;'\' "$__script_files_to_write"
	__write_env_val 'LIBPATH="$LIBPATH""$UniversalCRTSdkDir"'\''UnionMetadata\'\''"$UCRTVersion"'\'';'\' "$__script_files_to_write"
	__write_env_val 'LIBPATH="$LIBPATH""$UniversalCRTSdkDir"'\''References\'\''"$UCRTVersion"'\'';'\' "$__script_files_to_write"

	__script_files_to_write="$script_all,$script_dotnet,$script_single"

	__write_env_val ". $script_common" "$script_dotnet"
	__write_env_val '' "$__script_files_to_write"

	__search_dev_env_and_write "Framework40Version" "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val '' "$__script_files_to_write"

	__search_dev_env_and_write "__DOTNET_PREFERRED_BITNESS" "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val '' "$__script_files_to_write"

	__search_dev_env_and_write "FrameworkDir" "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write "FrameworkVersion" "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val '' "$__script_files_to_write"

	__search_dev_env_and_write "__DOTNET_ADD_32BIT" "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write "__DOTNET_ADD_64BIT" "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write "FrameworkVersion32" "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write "FrameworkVersion64" "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write "FrameworkDir32" "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write "FrameworkDir64" "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val '' "$__script_files_to_write"

	__search_dev_env_and_write "NETFXSDKDir" "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write "WindowsSDK_ExecutablePath_x86" "$__script_files_to_write" "$__mode_qoute_and_export"
	__search_dev_env_and_write "WindowsSDK_ExecutablePath_x64" "$__script_files_to_write" "$__mode_qoute_and_export"
	__write_env_val '' "$__script_files_to_write"

	__write_env_val 'FSHARPINSTALLDIR="$VSINSTALLDIR"'\''Common7\IDE\CommonExtensions\Microsoft\FSharp\Tools'\' "$__script_files_to_write" export
	__write_env_val '' "$__script_files_to_write"

	__write_env_val 'LIBPATH='\''C:\Windows\Microsoft.NET\Framework64\v4.0.30319;'\' "$script_dotnet" export
	__write_env_val 'LIBPATH="$LIBPATH"'\''C:\Windows\Microsoft.NET\Framework64\v4.0.30319;'\' "$script_all,$script_single"
	__write_env_val '' "$script_dotnet,$script_common,$script_vc,$script_single,$script_all"

	__write_env_val 'export PATH' "$script_dotnet,$script_common,$script_vc,$script_single,$script_all"

	local vc_path_file=vc_path.list
	local dotnet_path_file=dotnet_path.list
	local common_path_file=common_path.list

	if [ -f $vc_path_file ]; then rm $vc_path_file; fi
	if [ -f $dotnet_path_file ]; then rm $dotnet_path_file; fi
	if [ -f $common_path_file ]; then rm $common_path_file; fi

	local __check_perf=0
	local __check_arch=0

	for __path in $(cat "$path_file"); do
		case "$__path" in
		*VC* | *CMake* | *'Windows Kits'*)

			case "$__path" in
			*'bin/Host'*)
				if ((__check_arch)); then
					__path="${__path%/*}"/"$TARGET"
				else
					__path="${__path%/*}"/"$HOST"
				fi
				__check_arch=1
				__version="${__path/*'MSVC/'/}"
				__version="${__version/'/'*/}"
				if [[ "$__version" == [[:digit:]]*.[[:digit:]]*.*[[:digit:]] ]]; then
					__path="${__path/$__version/"$VC_TOOLS_VERSION"}"
				fi
				;;
			*'Windows Kits'*)
				__version="${__path/*'bin/'/}"
				__version="${__version/'/'*/}"
				if [[ "$__version" == [[:digit:]]*.[[:digit:]]*.[[:digit:]]*.*[[:digit:]] ]]; then
					__path="${__path/$__version/"$UCRT_SDK_VERSION"}"
				fi
				;;
			esac
			__write_env_val 'PATH='"$__path"':$PATH' "$script_vc,$script_single,$script_all" quotepath

			;;
		*NET* | *MSBuild* | *FSharp*)
			__write_env_val 'PATH='"$__path"':$PATH' "$script_dotnet,$script_single,$script_all" quotepath
			;;
		*)
			if [[ "$__path" == *'Performance Tools'* ]] && [[ "$TARGET" == x64 ]]; then

				if ((__check_perf)); then
					if [[ "$__path" != *x64 ]]; then
						__path="$__path"/"$TARGET"
					fi
				else
					if [[ "$__path" == *x64 ]]; then
						__path="${__path%/*}"
					fi
				fi
				__check_perf=1

			fi
			__write_env_val 'PATH='"$__path"':$PATH' "$script_common,$script_single" quotepath
			;;
		esac
	done

	echo $'\nVS PowerShell environment variables that were not written at place where were expected:'

	for _val in $(cat "$vars_file"); do
		local __exists=0
		for __val in $(cat "$script_single"); do
			if [[ "$__val" == export* ]]; then
				__val="${__val#export*[[:space:]]}"
				__val="${__val%%=*}"
				if [[ "$__val" == "$_val" ]]; then
					__exists=1
				fi
			fi
		done

		if ! ((__exists)); then
			case "$_val" in
			__VSCMD_PREINIT_PATH)
				_val="$_val (not written by default)"
				;;
			esac
			echo "$_val"
		fi
	done
}
