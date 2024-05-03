# vs2sh.sh

This is updated version of [dev_pws_to_bash.sh](../dev_pws_to_bash/dev_pws_to_bash.sh),
originally written around July of 2023.

Unlike original version, now it is a self-contained script that may be run under sh.

## IMPORTANT

This script was almost finished, but then was abandoned for some period of time.

After some time, instead of finishing this script, the author decided to write
completely [new script](https://github.com/maiddaisuki/vs2sh) instead.
It is recommended to use new script as this script will no longer be
updated. However, this script should be able to create working profiles as well.

This script uses pretty obscure sed scripts. GNU sed handles them, but author
cannot be sure if other implementations will handle them as well.

## Requirements

Following programs are required for script to run:

- **GNU sed** and **GNU grep** that support -E option and character classes
- iconv

The following programs will be used if they are found on the system:

- cygpath.

All these programs are available in [Cygwin](https://www.cygwin.com),
[Msys2](https://www.msys2.org) and [Git for Windows](https://gitforwindows.org).

While cygpath comes by default with Cygwin and Git for Windows,
in Msys2 it may be installed manually:

    pacman -Si cygpath

## Usage

### Environment files

As an **environment file** we refer to a file containing output of
**env** program without any options - newline-separated list of
envrionment variables with their values.

The **env** program comes with **Cygwin**, **Msys2** or **Git for Windows**.  
If you have **Git for Windows** installed in **C:\Git**, then you invoke it as:

    C:\Git\usr\bin\env

After you install Visual Studio it will create its folder in the Start Menu,
which will contain shortcuts to start **Developer PowerShell** and **Developer Command Prompt**.

Start any of them and then invoke **env** program without any arguments and redirect its output to file:

    Path/To/env >env_file

It is recommended to use **Developer Command Prompt** for wanted HOST/TARGET.

Do the same with default PowerShell or Command Prompt.

### Running the script

Invoke **vs2sh.sh** passing filenames of environment files:

    ./vs2sh.sh DEV_ENV_FILE USER_ENV_FILE

Note that order of arguments is reversed in comparison to [dev_pws_to_bash.sh](../dev_pws_to_bash)

Please make sure to run it from the same environment from which **env**
program has been called.

## Output

Unlike [dev_pws_to_bash](../dev_pws_to_bash/), all generated profile files are
self-contained now and do not depend on another generated files.

Following files are generated:

- vs_net.sh - profile to work with .NET tools only.
- vs_vc.sh - profile to work with Visual C tools only.
- vs.sh - combined profile to work with both .NET and Visual C tools.

### C++/CLI

Visual Studio has something names **C++/CLI** as a possible component
for installation. The author is not familiar with it.

If it happens that you need to use it, you probably need to use _combined_ (vs.sh) profile.

You may find more information about C++/CLI at
[Microsoft Docs](https://learn.microsoft.com/en-us/cpp/dotnet/dotnet-programming-with-cpp-cli-visual-cpp).

## Using generated profile files

Include it from your shell's startup files such as ~/.profile or ~/.bash_profile,
or with bash's --rcfile option.

If you include it from your regular startup files, it is recommended to include it
in the end of your regular startup files, so that PATH directories
from development environment will be searched first.

If you use --rcfile option, it is recommended to create new file which will
include your regular startup files and then include the generated profile file.

**The use of --rcfile should be considered a preferred way of using generated
profile files.**

Terminal emulators and code editors like Visual Studio Code allow you to create
multiple profiles. Create separate profile for use with Visual Studio tools and
use it when necessary.

## Variable substitution

This script will try to use variables that are defined in the profile file
earlier in values of variables defined later in the same file.

### Example

There is variable named **UCRTVersion** which contains version of Windows SDK.
There are other variables that contain its value literally, such as directories
in LIBPATH variable. Instead of keeping it that way, we will replace it with
reference to variable **UCRTVersion**.

This should allow you to simply change value of **UCRTVersion** in the
profile file to use another version of Windows SDK.

You may request some variables to be set by defining environment variables described below.

### Cygpath and PATH

If **cygpath** has been found on the system, the script will also perform
variable substitution on directories in the PATH variable. Profile created
this way should be usable from any environment that has cygpath program.

This includes **Cygwin** and **Git for Windows**, and **Msys2** if you have
cygpath installed. Unfortunately, **MinGW** (MinGW.org) does not have cygpath.

Also there is no way to generate profile file that does not use cygpath
if it has been found. As a workaround you may execute the script from
WSL on Windows, or another operating system such as GNU/Linux.

## Environment Variables

Following environment variables affect how profile files are generated:

- VS_UCRT_SDK_VERSION - specifies which version of Windows SDK to use when generating profiles.
  By default comes from environment file;
- VS_TOOLS_VERSION - specifies which version of Visual C tools to use when generating profiles.
  By default comes from environment file;
- VS_REDIST_VERSION - specifies which version of vcredist to use when generating profiles.
  By default comes from environment file;

In addition, the script checks for the following variables, however their support was not implemented:

- VS_HOST - specifies for what host to generate profile files.
  Expected values: x64 and x86;
- VS_TARGET - specifies for what target to generate profile files.
  Expected values: x64, x86, arm64 and arm;
