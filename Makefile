tar:
	rm -f distributed-make.tar.bz2 && cd .. && tar --exclude='distributed-make/.git' --exclude='distributed-make/.bundle' \
		--exclude='distributed-make/bin' --exclude='distributed-make/machines/.vagrant' -cJf distributed-make.tar.bz2 \
		distributed-make && mv distributed-make.tar.bz2 distributed-make/

