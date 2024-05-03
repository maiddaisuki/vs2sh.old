# dev_pws_to_bash.sh

This is the oldest version of the script, originally written around October of 2022.

## IMPORTANT

This script is considered obsolete and no longer updated. **USE AT YOUR OWN RISK**

**WARNING**: This script works _only_ with **bash** and SHOULD NOT be run
under **sh**

Besides obscure coding style and variable names this script may contain bugs
and may not work at all with newer versions of Visual Studio.

## Usage

You must read this script with **.** or **source** builtin and then manually
invoke dev_pws_to_bash function with two arguments:

1. Filename of file containing regular, non-development environment
2. FIlename of file containing development environment

You may create wrapper script that contains:

    #!/bin/bash

    source dev_pws_to_bash.sh && dev_pws_to_bash "$@"

## Output

This script produces 5 files:

- vs_common.sh - contains variables shared with other files.
- vs_dotnet.sh - contains variables requred to work with .NET tools (C#, FSharp, et cetera), includes vs_common.sh.
- vs_vc.sh - contains variables required to work with C/C++ tools (cl, nmake, et cetera), includes vs_common.
- vs_all.sh - combined profile to work with all tools, inclues vs_common.sh.
- vs_single.sh - combined self-contained profile to work wiff all tools, unlike vs_all.sh it does not depend on vs_common.sh.

These files are written into **.env_output/** directory by default.

Beside files mentioned above, it also produces auxiliary output files:

- path.list - contains entries of PATH variable exclusive to development environment.
- vars.list - contains names of variables exclusive to development environment.
- variables.list - contains list of variables exclusive to development environemnt.
- redists.list - contains list of installed version of vcredist.
- sdks.list - contains list of installed version of Windows SDK.
- tools.list - contains list of inetalled version of Visual C tools.

These files are written into **.env_dump/** directory by default.

The **redists.list**, **sdks.list** and **tools.list** are written only if
directories specified in the development environment file exist. This means
you should run the script on the same system where the environment files
were generated.

## Environment variables

You may modify how dev_pws_to_bash produces its output by defining following
environment variables:

- OUTPUT_PREFIX - specifies directory where to write resulting profiles.
  Default directory is **.env_output/**;
- DUMP_PREFIX - specifies directory where to write auxilary files.
  Default directory is **.env_dump/**;
- HOST - specifies for what host to generate profile files.
  Expected values: x64 and x86;
- TARGET - specifies for what target to generate profile files.
  Expected values: x64, x86, arm64 and arm;
- UCRT_SDK_VERSION - specifies which version of Windows SDK to use when generating profiles.
  By default comes from environment file;
- VC_TOOLS_VERSION - specifies which version of Visual C tools to use when generating profiles.
  By default comes from environment file;
- VC_REDIST - specifies which version of vcredist to use when generating profiles.
  By default comes from environment file;

Valid value for **UCRT_SDK_VERSION**, **VC_TOOLS_VERSION** and **VC_REDIST**
maybe found in auxilary files **sdks.list**, **tools.list** and **redists.list**
respectively.
