### Things you want before running this:  p7zip, grep, gawk/mawk, bash

SHELL          := /bin/bash
HASHES_URL     := https://downloads.pwnedpasswords.com/passwords/pwned-passwords-sha1-ordered-by-hash-v5.7z.torrent
HASHES_TORRENT := pwned-passwords-sha1-ordered-by-hash-v5.7z.torrent
HASHES_7Z      := pwned-passwords-sha1-ordered-by-hash-v5.7z
HASHES_TEXT    := pwned-passwords-sha1-ordered-by-hash-v5.txt
HASHES_DATA    := hashes.data
HASH_SAMPLE    := 0000000FC1C08E6454BED24F463EA2129E254D43

SQLITE3_BIN    := /usr/local/sqlite-3.31.1a/bin/sqlite3

.DEFAULT_GOAL  := fgrep

$(HASHES_7Z):
	aria2c --file-allocation=falloc $(HASHES_URL)

$(HASHES_TEXT): $(HASHES_7Z)
	### very slow, avoid if you can
	-7z x -bt -aot $^
	sync; sync

$(HASHES_DATA): $(HASHES_TEXT)
	/bin/time mawk -F: '{print $$1}' $^ \
	| sort -u -o $@
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


methodA: $(HASHES_DATA)
	mkdir -p methodA/data/{0000..FFFF}
	#:TODO: sort out entries starting with 0000 into 0000/hashes.data, 0001/hashes.data ...

.ONESHELL:
sqlite3A/hashes.sqlite3: $(HASHES_DATA)
	-$(RM) $@
	#sqlite3 $@ "create table textTable (hashnum TEXT);"
	$(SQLITE3_BIN) $@ "create table numericTable (hashnum NUMERIC);"
	#sqlite3 $@ "PRAGMA cache_size = 400000; PRAGMA locking_mode = EXCLUSIVE; PRAGMA synchronous = OFF; PRAGMA journal_mode = WAL;"
	$(SQLITE3_BIN) -stats $@ ".import $(HASHES_DATA) numericTable"
	#$(SQLITE3_BIN) -stats $@ "create index idx_hashnums on numericTable(hashnum);"
	$(SQLITE3_BIN) -stats $@ "BEGIN; create index idx_hashnums on numericTable(hashnum); COMMIT;"

	###:TODO: BLOB vs INTs vs TEXT
	###:TODO: BEGIN; create index; COMMIT;
	###:TODO: bench them
	###:FIXME: why create unique index does not work?

sqlite3_sample_indexednot_warmcache: sqlite3A/hashes.sqlite3.orig
	sudo perf stat -S -ddd -e '{xfs:*,block:*,filelock:*,filemap:*,tlb:*,writeback:*}' -- \
		$(SQLITE3_BIN) -stats -readonly $^ \
			"select hashnum from numericTable where hashnum='$(HASH_SAMPLE)';" \
			 2>&1 | tee $@

sqlite3_sample_indexednot_coldcache: sqlite3A/hashes.sqlite3.orig
	sync; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches;
	sudo perf stat -S -ddd -e '{xfs:*,block:*,filelock:*,filemap:*,tlb:*,writeback:*}' -- \
		$(SQLITE3_BIN) -stats -readonly $^ \
			"select hashnum from numericTable where hashnum='$(HASH_SAMPLE)';" \
			 2>&1 | tee $@

sqlite3_sample_indexed_warmcache: sqlite3A/hashes.sqlite3
	sudo perf stat -S -ddd -e '{xfs:*,block:*,filelock:*,filemap:*,tlb:*,writeback:*}' -- \
		$(SQLITE3_BIN) -stats -readonly $^ \
			"select hashnum from numericTable where hashnum='$(HASH_SAMPLE)';" \
			 2>&1 | tee $@

sqlite3_sample_indexed_coldcache: sqlite3A/hashes.sqlite3
	sync; sync; echo 3 | sudo tee /proc/sys/vm/drop_caches;
	sudo perf stat -S -ddd -e '{xfs:*,block:*,filelock:*,filemap:*,tlb:*,writeback:*}' -- \
		$(SQLITE3_BIN) -stats -readonly $^ \
		"select hashnum from numericTable where hashnum='$(HASH_SAMPLE)';" \
			 2>&1 | tee $@

perf: sqlite3_sample_indexed_coldcache sqlite3_sample_indexed_warmcache sqlite3_sample_indexednot_coldcache sqlite3_sample_indexednot_warmcache

.PHONY: fgrep ggrep egrep egrepB pgrep perf sqlite3_sample_indexed_coldcache sqlite3_sample_indexednot_warmcache sqlite3_sample_indexednot_coldcache sqlite3_sample_indexednot_warmcache
#vim set ft=make sts=4 sw=4 ts=4 et
