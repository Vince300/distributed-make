tar:
	rake examples:clean
	rm -f distributed-make.tar.xz && cd .. && tar --exclude='distributed-make/.git' --exclude='distributed-make/.bundle' \
		--exclude='distributed-make/bin' --exclude='distributed-make/machines/.vagrant' --exclude 'distributed-make/log*' \
		--exclude='distributed-make/spec/fixtures/matrix' --exclude='distributed-make/spec/fixtures/simple' \
		--exclude='distributed-make/*.tar.gz' -cJvf distributed-make.tar.xz \
		distributed-make && mv distributed-make.tar.xz distributed-make/

dist:
	rake examples:clean
	rm -f distributed-make-rendu.tar.xz && cd .. && tar --exclude='distributed-make/.git' --exclude='distributed-make/.bundle' \
		--exclude='distributed-make/bin' --exclude='distributed-make/machines/.vagrant' --exclude 'distributed-make/log*' \
		--exclude='distributed-make/spec/fixtures/simple' --exclude='distributed-make/*.tar.*' -cJvf distributed-make-rendu.tar.xz \
		--exclude='distributed-make/.idea' --exclude='distributed-make/.yardoc' --exclude='*.pptx' --exclude='*.docx' --exclude='*.xlsx' \
		--exclude='distributed-make/coverage' distributed-make && mv distributed-make-rendu.tar.xz distributed-make/

send: tar
	echo "put distributed-make.tar.xz grenoble" | sftp grid5000
