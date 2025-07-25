all:
	@test -n "$(IMAGE)" || { echo specify 'IMAGE=...' ; false ; }
	$(MAKE) -j4 download

download: download.x86_64 download.ppc64le download.aarch64 download.s390x
images:   image.x86_64    image.ppc64le    image.aarch64    image.s390x
vms:      vm.x86_64       vm.ppc64le       vm.aarch64       vm.s390x
tickets:  ticket.x86_64   ticket.ppc64le   ticket.aarch64   ticket.s390x

vm.%: ticket.%
	ticket_id=`cat ticket.$*` \
	&& data=`resalloc ticket-wait $$ticket_id` \
	&& echo "$$data" | yq .host > $@ ; \
	ip=`cat $@` ; \
	host=root@$$ip ; \
	echo $$host ; \
	cat prepare-worker | ssh $$host 'cat > /tmp/prepare-worker' ; \
	ssh $$host "bash -x /tmp/prepare-worker"

ticket.%:
	tag=`resalloc ticket --tag arch_$*` && echo "$$tag" > $@

image.%: vm.%
	@test -n "$(IMAGE)" || { echo specify 'IMAGE=...' ; false ; }
	set -x ; ip=`cat vm.$*` ; host=root@$$ip ; \
	rsync_host=root@[$$ip] ; \
	cat build-images.sh | ssh $$host 'cat > /tmp/build-images.sh' ; \
	cat copr-build-image-bootc.sh | ssh $$host 'cat > /tmp/copr-build-image-bootc.sh' ; \
	ssh $$host "IMAGE=$(IMAGE) ARCH=$* bash -x /tmp/build-images.sh" && \
	touch "$@"

download.%: image.%
	set -x ; ip=`cat vm.$*` ; host=root@$$ip ; \
	outputdir=/var/lib/copr/public_html/images/`date -I`/$* ; \
	test -e $$outputdir && mv $$outputdir $${outputdir}-backup ; \
	mkdir -p "$$outputdir" ; \
	for image in `ssh "$$host" 'find /tmp -size +200M'`; do \
	  name=`basename $$image` ; \
	  ssh "$$host" "gzip < $$image" | pv | gzip -d > "$$outputdir/$$name" ; \
	done

.PHONY: clean download

clean: clean.x86_64 clean.ppc64le clean.aarch64 clean.s390x

clean.x86_64 clean.ppc64le clean.aarch64 clean.s390x:
	set -x ; \
	arch=$@ ; \
	arch=$${arch//clean./} ; \
	if test -f ticket.$$arch; then \
	   ticket_id=`cat ticket.$$arch` ; \
	   resalloc ticket-close $$ticket_id ; \
	   rm -rf vm.$$arch ticket.$$arch image.$$arch; \
	fi
