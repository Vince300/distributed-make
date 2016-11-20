tar:
	rake examples:clean
	rm -f distributed-make.tar.bz2 && cd .. && tar --exclude='distributed-make/.git' --exclude='distributed-make/.bundle' \
		--exclude='distributed-make/bin' --exclude='distributed-make/machines/.vagrant' --exclude 'distributed-make/log*' \
		--exclude='distributed-make/spec/fixtures/matrix' --exclude='distributed-make/spec/fixtures/simple' \
		--exclude='distributed-make/*.tar.gz' -cJvf distributed-make.tar.bz2 \
		distributed-make && mv distributed-make.tar.bz2 distributed-make/

send: tar
	echo "put distributed-make.tar.bz2 grenoble" | sftp grid5000
