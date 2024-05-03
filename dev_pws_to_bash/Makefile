SHELL = /bin/bash

DUMP_PREFIX = .env_dump
OUTPUT_PREFIX = .env_output

dirs = $(OUTPUT_PREFIX) $(DUMP_PREFIX)

.PHONY:all
all:run

.PHONY:run
run:
	. dev_pws_to_bash.sh && dev_pws_to_bash $(USER_ENV) $(DEV_ENV)

.PHONY:clean
clean:
	rm -rf $(dirs)
