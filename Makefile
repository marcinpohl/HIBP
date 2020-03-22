### Things you want before running this:  p7zip, grep, awk, bash

SHELL := /bin/bash
HASHES_URL := 'https://downloads.pwnedpasswords.com/passwords/pwned-passwords-sha1-ordered-by-hash-v5.7z.torrent'
HASHES_TORRENT := 'pwned-passwords-sha1-ordered-by-hash-v5.7z.torrent'
HASHES_7Z      := 'pwned-passwords-sha1-ordered-by-hash-v5.7z'
HASHES_TEXT    := 'pwned-passwords-sha1-ordered-by-hash-v5.txt'
HASHES_DATA    := 'hashes.data'
HASH_SAMPLE    := '0000000FC1C08E6454BED24F463EA2129E254D43'


$(HASHES_TORRENT)
	aria2c --out=$@ $(SRCURL)

$(HASHES_7Z): $(HASHES_TORRENT)
	aria2c --file-allocation=falloc --out=$@ -T $^

$(HASHES_TEXT): $(HASHES_7Z)
	7z x $^
	sync; sync

fgrep: $(HASHES_DATA)
	/bin/time -v grep -F $(HASH_SAMPLE)   $^

ggrep: $(HASHES_DATA)
	/bin/time -v grep -Gx $(HASH_SAMPLE) $^

egrep: $(HASHES_DATA)
	/bin/time -v grep -Ex $(HASH_SAMPLE) $^

egrepB: $(HASHES_DATA)
	/bin/time -v grep -E ^$(HASH_SAMPLE)$$ $^

pgrep: $(HASHES_DATA)
	/bin/time -v grep -Px $(HASH_SAMPLE) $^

#vim set ft=make sts=4 sw=4 ts=4 et
