# eagle-tools.sh

A collection of small bash scripts that I frequently use on HPCs. Wrapped into
a tools with subcommands and getopts for convinience.

```
usage: eagle-tools.sh [-h] SUBCOMMAND ...

Subcommands:
pinfo   Get information about available partitions (name, nodes, cpus,
        memory/node). Takes no arguments.

cbf     "Compare Big File", computes a md5sum of N initial lines
        (default is 1000, can be specified by -s N). Run with -h for
        help. Gzipped files MUST be passed with -g option

sampler Used to generate smaller versions from large fasta/fastq files
        for pipeline testing. [under construction, can't be invoked yet]

sfa     "Split FASTA", splits a multi header fasta into separate files.
        Might be useful for disassembling genomes into chromosomes. Use
        -g for gzipped files

eln     "Executable ln", creates a link to specified file in my $PATH

ttmd    "table to Markdown", takes a table with arbitrary separator
        (specified by -s if other than whitespace) and outputs a
        Markdown formated table. First row is treated as header.

sin     "Script Init", creates a script with the name provided as 1st
        argument, and fills it with necessary boring boilerplate

shide   Hide the  files from view.

inter   Run interactive job from preset.
        light:           4 CPUs,  16G RAM, 1 day
        medium:          8 CPUs,  32G RAM, 2 days
        heavy:          32 CPUs, 128G RAM, 7 days
        hic (high CPU): 32 CPUs,  16G RAM, 2 days
        him (high mem):  8 CPUs, 128G RMA, 2 days
```
