# FQ Toolbox Docker image  
_`fqtools` + a **fully-matched HTS stack v 1.21** (samtools / bcftools / htslib)_  

[![Docker Automated build](https://img.shields.io/badge/docker-build-green)](https://hub.docker.com/r/<your-org>/fqtools)

---

## Why we pin everything to **1.21**

| component | upstream 1.22+ change | breakage observed | workaround in this image |
|-----------|-----------------------|-------------------|--------------------------|
| **HTSlib** | `<sam.h>`, `<bam.h>` and friends moved from the project root into `htslib/` | `fqtools` still does <br>`#include <sam.h>` → compile fails (`fatal error: sam.h`) | ship **HTSlib 1.21** (last release with “legacy” headers) and patch `fqtools` to include `htslib/sam.h` for future-proofing |
| **samtools / bcftools** | must be **ABI-compatible** with the same HTSlib | mixing versions triggers runtime loader errors | build **samtools 1.21** and **bcftools 1.21** from tarballs |
| **GCC 10+** (default on Ubuntu 22.04) | new default `-fno-common` breaks a few duplicated globals in `fqtools` | linker errors with “multiple definition …” | compile `fqtools` with `-fcommon` |

Keeping the whole stack on **1.21** means:

* no source-level patches to third-party code  
* stable ABI / headers for every program inside the container  
* reproducible results across clusters and CI

---

## Image layout

| stage | why it exists |
|-------|---------------|
| **HTS stack build** | build & install HTSlib 1.21 + samtools / bcftools 1.21 – provides the runtime libraries and CLIs you already know (`samtools`, `bgzip`, `tabix`, …) |
| **`fqtools` build** | *vendored* copy of HTSlib 1.21 is built **only for its headers** so that `fqtools` can compile; binary is installed to `/usr/local/bin/fqtools` |
| **strip tool-chain** | we remove the compiler & dev packages afterwards so the final image stays slim (~125 MB) |

---

## Build the image (one-off)

```bash
git clone https://github.com/<your-org>/fqtools-docker.git
cd fqtools-docker
docker build -t fqtools:1.21 .
```

⸻

Run fqtools non-interactively on many FASTQ files

Assume you have:

/home/alice/reads/
  ├─ sampleA_R1.fq.gz
  ├─ sampleA_R2.fq.gz
  ├─ sampleB_R1.fq.gz
  └─ …

1  Validate every file (batch loop)

```
docker run --rm \
  -v /home/alice/reads:/in:ro \
  -v /home/alice/reads:/out \
  fqtools:1.21 \
  bash -c 'for f in /in/*.fq.gz; do
              fqtools validate "$f" \
                > "/out/$(basename "$f").validation";
           done'
```

	•	read-only bind for safety (/in)
	•	same folder re-mounted writeable (/out)
	•	container vanishes when loop is done (--rm)

2  Read-length histogram for one sample

docker run --rm -v /home/alice/reads:/data:ro fqtools:1.21 \
  fqtools lengthtab /data/sampleA_R1.fq.gz \
  > /home/alice/reads/sampleA_R1.lengths.txt

3  Convert all *_R1.fq.gz to FASTA

docker run --rm \
  -v /home/alice/reads:/in:ro \
  -v /home/alice/reads:/out \
  fqtools:1.21 \
  bash -c 'for f in /in/*_R1.fq.gz; do
              base=${f##*/}; base=${base/_R1.fq.gz/}
              fqtools fasta "$f" > "/out/${base}.fa"
           done'

4  Pipe data through stdin (no file inside the container)

zcat /home/alice/reads/sampleA_R1.fq.gz | \
  docker run --rm -i fqtools:1.21 fqtools stats -



⸻

Design principles

principle	manifestation in this image
Isolation	all compilers & libraries live inside the image – the host stays clean
Reproducibility	Ubuntu 22.04 + fully pinned 1.21 HTS stack
Stateless	--rm so containers never keep state between runs
Non-interactive batch	loops passed via bash -c – no shell login needed
Volume mounts	data are streamed through -v binds, never copied into the image



⸻

Patch notes / gotchas
	•	Issue #18 in fqtools repo – fixed by rewriting the two outdated
includes.
	•	GCC 10 duplicate-symbol errors – compiled with -fcommon.
	•	samtools tview needs libncursesw5-dev; that dev package is present
only at build time, but the runtime ncurses libraries are baked into
Ubuntu 22.04 so tview still works inside the final image.

⸻

FAQ
	•	Q: Can I mount a directory read-only?
A: Yes – prepend :ro to the -v spec.
	•	Q: Will this break if I upgrade HTSlib on the host?
A: No. The container carries its own copy of all libraries.
	•	Q: Does fqtools support BAM input?
A: Yes – that’s why we ship HTSlib inside the image.

⸻

License
	•	fqtools & HTSlib stack: their respective open-source licences.
	•	Dockerfile & documentation: © 2025 Anton Zhelonkin – MIT licence.