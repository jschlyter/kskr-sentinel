KEYDIR=		keys

KSK1=		K.+008+54346
KSK2=		K.+008+28972
ZSK=		K.+008+24279

90DAYS=		7776000

ROOTZONE=	root.zone

sign: root.zone.signed

root.zone.unsigned: $(ROOTZONE)
	cat $< $(KEYDIR)/K*.key > $@

root.zone.signed: root.zone.signed.part1 root.zone.signed.part2
	cat root.zone.signed.part1 root.zone.signed.part2 > $@
	ldns-verify-zone $@

# generate a zone signed where records are signed by KSK1/ZSK as usual
root.zone.signed.part1: root.zone.unsigned
	dnssec-signzone -at -x -K $(KEYDIR) -e "now+$(90DAYS)" \
	-o . -f $@.tmp $< $(KSK1) $(ZSK)
	named-checkzone -D . $@.tmp | grep -v resign= | egrep -v "^sentinel.+RRSIG\tA" > $@
	rm -f $@.tmp

# generate a zone signed where all records are signed by KSK2 
root.zone.signed.part2: root.zone.unsigned
	dnssec-signzone -at -z -K $(KEYDIR) -e "now+$(90DAYS)" \
	-o . -f $@.tmp $< $(KSK2)
	named-checkzone -D . $@.tmp | egrep "^sentinel.+RRSIG\tA" > $@
	rm -f $@.tmp

clean:
	rm -f root.zone.signed.part*
	rm -f root.zone.signed
	rm -f root.zone.unsigned
	rm -f dsset-.

# used once, update KSK/ZSK files in makefile if regenerated
keys::
	mkdir $(KEYDIR)
	dnssec-keygen -K$(KEYDIR) -a RSASHA256 -n ZONE -f KSK -b 2048 .
	dnssec-keygen -K$(KEYDIR) -a RSASHA256 -n ZONE -f KSK -b 2048 .
	dnssec-keygen -K$(KEYDIR) -a RSASHA256 -n ZONE -b 1024 .

# start root server on port 5300
run-named-auth:
	named -g -c named-authoritative.conf

# start recursive nameserver on port 5301
run-named-rec:
	named -g -c named-recursive.conf

# try to resolve sentinel using Unbound (depends on running auth server)
test-unbound:
	unbound-host -C unbound.conf -F trusted-keys.conf -dvv -t A sentinel.

# try to resolve sentinel using BIND (depends on running auth+rec servers)
test-bind:
	dig +dnssec @127.0.0.1 -p5301 sentinel. A
