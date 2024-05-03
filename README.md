# vs2sh (old versions)

This repository contains older versions of vs2sh.sh script.

**USE SCRIPT IN THIS REPOSITORY AT YOUR OWN RISK.**

All users must use [new version of the script](https://github.com/maiddaisuki/vs2sh).

## Scripts

This repository contains follwoing scripts:

- [dev_pws_to_bash.sh](dev_pws_to_bash/) - original version of the script.
- [vs2sh.sh](vs2sh/) - updated version of the original script.

## Running

You may run both scripts with make:

    make DEV_ENV=path_to_dev_env_file USER_ENV=path_to_user_env_file

Make will recurse into subdirectories so make sure values of DEV_ENV and
USER_ENV are absolute filenames, for example:

    make DEV_ENV=$(pwd)/relative/path USER_ENV=/absolute/path

To remove all generated files:

    make clean

## Licence

All scripts in this repository are licensed under terms of GNU General Public
License Version 3. See [LICENSE](LICENSE) for details.
