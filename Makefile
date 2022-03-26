BIN	= tarsnaps
SRC	= $(BIN).sh
MAN	= $(BIN).8

PREFIX	= /usr/local
BINDIR	= $(PREFIX)/bin
MANDIR	= $(PREFIX)/man/man8

DIFF	= gnu-date.patch

all: $(BIN)

clean:
	rm -f $(BIN)

patch:
	patch -p0 < $(DIFF)

install: $(BIN)
	install -m0755 $(BIN) $(BINDIR)
	install -m0644 $(MAN) $(MANDIR)

uninstall:
	rm -f $(BINDIR)/$(BIN)
	rm -f $(MANDIR)/$(MAN)

.PHONY: all clean patch install uninstall
