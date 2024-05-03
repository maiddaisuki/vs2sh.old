SHELL = /bin/sh

.PHONY:all
all:dev_pws_to_bash vs2sh

.PHONY:clean
clean:clean-dev_pws_to_bash clean-vs2sh

.PHONY:dev_pws_to_bash vs2sh
dev_pws_to_bash vs2sh:
ifeq (,$(DEV_ENV))
	$(error DEV_ENV variable is not set)
endif
ifeq (,$(USER_ENV))
	$(error USER_ENV variable is not set)
endif
	@$(MAKE) -C $@

.PHONY:clean-dev_pws_to_bash
clean-dev_pws_to_bash:
	@$(MAKE) -C dev_pws_to_bash clean

.PHONY:clean-vs2sh
clean-vs2sh:
	@$(MAKE) -C vs2sh clean
