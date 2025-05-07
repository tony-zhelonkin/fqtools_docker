# FQ Toolbox Docker Image

A self-contained container with

| Tool | Version | Notes |
|------|---------|-------|
| Ubuntu | 22.04 | glibc 2.35 |
| HTSlib | 1.21 | last release with `<sam.h>` in project root |
| samtools | 1.21 | matches HTSlib ABI |
| bcftools | 1.21 | matches HTSlib ABI |
| fqtools | latest (`main`) | **patched** for issue [#18](https://github.com/alastair-droop/fqtools/issues/18) |

## Why the 1.21 stack?

HTSlib ≥ 1.22 moved header files to `htslib/`, breaking `fqtools`, which
still does:

```c
#include <sam.h>

Instead of patching dozens of includes, we
	1.	build HTSlib 1.21, where sam.h and bam.h are still in the
top-level directory, and
	2.	one-line-patch fqheader.h to point at
"htslib/sam.h" / "htslib/bam.h" (exactly the workaround discussed
in issue #18).

Everything now compiles and links without touching the rest of the
source tree.

---

## Quick start

```bash
# clone repo (or just copy Dockerfile) and build once
docker build -t fqtools:1.21 .



⸻

Non-interactive batch recipes

Assume your host folder contains compressed FASTQ files:

/home/user/reads/
 ├── sampleA_R1.fq.gz
 ├── sampleA_R2.fq.gz
 └── sampleB_R1.fq.gz

Mounts used below
	•	/in  – read-only view of your data (:ro)
	•	/out – same host folder, but writable, to save results

1  Validate every file

docker run --rm \
  -v /home/user/reads:/in:ro \
  -v /home/user/reads:/out \
  fqtools:1.21 \
  bash -c 'for f in /in/*.fq.gz; do
              fqtools validate "$f" \
              > "/out/$(basename "$f").validation";
           done'

Each *.validation report lands next to its source FASTQ.

⸻

2  Read-length histogram for one file

docker run --rm \
  -v /home/user/reads:/data:ro \
  fqtools:1.21 \
  fqtools lengthtab /data/sampleA_R1.fq.gz \
  > /home/user/reads/sampleA_R1.len



⸻

3  Convert every R1 file to FASTA

docker run --rm \
  -v /home/user/reads:/in:ro \
  -v /home/user/reads:/out \
  fqtools:1.21 \
  bash -c 'for f in /in/*_R1.fq.gz; do
              base=$(basename "${f/_R1.fq.gz/}");
              fqtools fasta "$f" > "/out/${base}.fa";
           done'



⸻

4  Stream from stdin (no temp files)

zcat /home/user/reads/sampleA_R1.fq.gz | \
  docker run --rm -i fqtools:1.21 fqtools stats -



⸻

Container principles

Principle	How it’s met here
Isolation	All compilers / libs live inside the image; host stays clean.
Reproducibility	Exact versions pinned (Ubuntu 22.04 + HTS 1.21 stack).
Stateless	--rm removes the container when the job ends.
Volume mounts	-v host:container passes data without copying.
Batch automation	Loops run under bash -c '…', perfect for pipelines/HPC.

Drop the commands above into Nextflow, Snakemake, CWL, SLURM, or plain
shell scripts and be sure every run uses the same, HTSlib-compatible
fqtools build.

---
# fqtools_docker
