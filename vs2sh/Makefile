SHELL = /bin/sh

files = vs.sh vs_net.sh vs_vc.sh

.PHONY:all
all:run

.PHONY:run
run:
	./vs2sh.sh $(DEV_ENV) $(USER_ENV)

.PHONY:clean
clean:
	rm -f $(files)
