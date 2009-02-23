CENTER="Virtual Machine Install Tools"


all: virt-install.1 virt-image.1 virt-clone.1 virt-image.5 virt-convert.1

html: virt-install.html virt-clone.html virt-image.html virt-image-xml.html virt-convert.html

clean:
	rm *.1 *.5

%.1: %.pod
	pod2man --center=$(CENTER) $< $@

%.html: %.pod
	pod2html --header --podpath . --infile $< --outfile $@

virt-image.5: virt-image-xml.pod
	pod2man --center=$(CENTER) --section=5 --name=virt-image $< $@
