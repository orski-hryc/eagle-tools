#!/usr/bin/env bash

# A set of small tools that I find useful when working on HPC clusters, made
# accessible by subcommande like 'pinfo'

set -e
set -o pipefail

# === Parsing config ===

# I need to think about this...
#CFG_PATH="$(awk -F ' = ' '$1 == "executable_path" {print $2}' config)"
CFG_PATH=/home/maciej/.local/bin/

# === Help/usage ===

help() {
cat << EOF
usage: eagle-tools.sh [-h] SUBCOMMAND ...

Subcommands:
pinfo	Get information about available partitions (name, nodes, cpus,
	memory/node). Takes no arguments.

cbf	"Compare Big File", computes a md5sum of N initial lines
	(default is 1000, can be specified by -s N). Run with -h for
	help. Gzipped files MUST be passed with -g option

sampler	Used to generate smaller versions from large fasta/fastq files
	for pipeline testing. [under construction, can't be invoked yet]

sfa	"Split FASTA", splits a multi header fasta into separate files.
	Might be useful for disassembling genomes into chromosomes. Use
	-g for gzipped files

eln	"Executable ln", creates a link to specified file in my \$PATH

ttmd	"table to Markdown", takes a table with arbitrary separator
	(specified by -s if other than whitespace) and outputs a
	Markdown formated table. First row is treated as header.

sin	"Script Init", creates a script with the name provided as 1st
	argument, and fills it with necessary boring boilerplate

shide	Hide the `slurm-35581944.out` files from view.

inter	Run interactive job from preset.
	light:		 4 CPUs,  16G RAM, 1 day
	medium:		 8 CPUs,  32G RAM, 2 days
	heavy:		32 CPUs, 128G RAM, 7 days
	hic (high CPU):	32 CPUs,  16G RAM, 2 days
	him (high mem):  8 CPUs, 128G RMA, 2 days
EOF
}

#
# === Subcommand functions ===
#

pinfo() {
	#
	# Partition info
	# Print info about accessible partitions as a nice table
	#
	sinfo -o "%P %D %c %m %l" | \
		awk '{printf("%-16s\t%5s\t%10s\t%12s\n", $1, $2, $3, $4/1000, $5)}' || \
		echo "It seems you are not working on a SLURM HPC"
}
cbf() {
	#
	# Compare Big File
	# prints md5sum of head -n N lines from files. Used to get an idea if
	# two or more files are likely identical
	#
	cbf_help() {
cat << EOF
usage: eagle-tools.sh cbf [-s SIZE] [-g] FILE

-s	Size (number of lines) that are fed into md5sum. Default is
	1000.

-g	Use for gzipped files to feed the text content into md5sum.
EOF
	}

	size=1000; g_zip=0

	while getopts 's:gh' opt; do
		case $opt in
			s) size=${OPTARG} ;;
			g) g_zip=1 ;;
			h) cbf_help >&2; exit 0 ;;
			*) echo 'Something is not right...' >&2; exit 1 ;;
		esac
	done

	# handle 0 arguments scenario
	[[ ! $opt_provided ]] && cbf_help; exit 1

	shift $((OPTIND - 1)); name=$(basename $1)

	[[ g_zip -eq 1 ]] && \
		md5sum <(zcat $1 | head -n $size) | \
		awk -v name=$name '{printf("%s\t%s\n", $1, name)}' \
		|| \
		md5sum <(head -n $size $1) | \
		awk -v name=$name '{printf("%s\t%s\n", $1, name)}'
}
sampler() {
	#
	# Sample reads from fasta/fastq
	# prints md5sum of head -n N lines from files. Used to get an idea if
	# two or more files are likely identical
	#
	sampler_help() {
cat << EOF
usage: eagle-tools.sh sampler [-s SIZE] [-g] FILE

-s	Size (number of lines) that are coppied. Default is 1000.

-g	Use for gzipped files to feed the text content into md5sum.
EOF
	}

	size=1000; g_zip=0

	while getopts 's:gh' opt; do
		case $opt in
			s) size=${OPTARG} ;;
			g) g_zip=1 ;;
			h) sampler_help >&2; exit 0 ;;
			*) echo 'Something is not right...' >&2; exit 1 ;;
		esac
	done
}
sfa() {
	#
	# Splits a multi header fasta into separate files.
	#
	g_zip=0
	while getopts 'g' opt; do
		case $opt in
			g) g_zip=1 ;;
			*) echo 'Something is not right...' >&2; exit 1 ;;
		esac
	done

	shift $((OPTIND - 1))

	[[ $g_zip -eq 1 ]] && \
		csplit -f chr <(zcat $1) '/^>/' '{*}' || \
		csplit -f chr $1 '/^>/' '{*}'
}
eln() {
	eln_help() {
cat << EOF
usage: eagle-tools.sh eln [-p PATH] [-n NAME] FILE

-p	Symlink destination, default is set in DEFAULT_PATH variable.

-n	Name of the link, default is the executable name
EOF
	}
	path=$CFG_PATH

	while getopts 'p:n:h' opt; do
		case $opt in
			p) path=${OPTARG} ;;
			n) name=${OPTARG} ;;
			h) eln_help; exit 0 ;;
			*) echo 'Something is not right...' >&2; exit 1 ;;
		esac
	done

	shift $((OPTIND - 1))

	[[ -z $@ ]] && echo "No files provided" && exit 1

	# exit if already linked to $PATH
	[[ -h ${path}$1 ]] || [[ -h ${path}${name} ]] && \
		echo "Link already exists in \$PATH ${path}, skipping" && exit 0

	# add x permission just in case
	chmod +x $1
	[[ -z $name ]] && \
		ln -s $(pwd)/$1 ${path}$1 || \
		ln -s $(pwd)/$1 ${path}${name}

	echo "linked $1 to ${path}"
}
ttmd() {
	ttmd_help() {
cat << EOF
usage: eagle-tools.sh ttmd [-s SEPARATOR] FILE

-s	Separator used in the input FILE. Can be anything, most common would be
	'\t', ';', ','
EOF
	}
	SEP='\t'
	while getopts 's:h' opt; do
		case $opt in
			s) SEP="$OPTARG" ;;
			h) ttmd_help; exit 0 ;;
			*) echo 'Something is not right...' >&2; exit 1 ;;
		esac
	done

	shift $((OPTIND - 1))

	awk -F "${SEP}" -v SEP="${SEP}" '
	function format() {
		split($0, arr, SEP, seps); 
		for (i = 1; i <= NF; i++) {
			printf("| %s ", arr[i])
		}
		printf("|\n")
	};
	function make_line() {
		for (i = 1; i <= NF; i++) {
			printf("%s", "| --- ")
		}
		printf("%s", "|\n")
	}; FNR == 1 {
		format();
		make_line()
	}; FNR != 1 {format()}' $1
}
sin() {
	#
	# Create shell script scaffold
	#

	# don't destroy files and exit
	fail() {
		echo $1 exists, exiting
		exit 1
	}

	# exit if no args (filename) were given
	[[ $# -eq 0 ]] && echo 'No filename given, exiting' && exit 1

#	[[ -e $1 ]] && \
#		echo '#!/usr/bin/env bash' > $1 || \
#		fail $1
	if [[ ! -e $1 ]]; then
		echo '#!/usr/bin/env bash' > $1
	else
		fail $1
	fi
}

shide() {
	[[ ! -d .slurm_outs ]] && mkdir -p .slurm_outs

	mv slurm-*.out .slurm_outs
}


inter() {
	local CPU
	local MEM
	local TIME

	if [[ $1 == "light" ]]; then
		CPU=4
		MEM="16G"
		TIME="1-00:00:00"
	elif [[ $1 == "medium" ]]; then
		CPU=8
		MEM="32G"
		TIME="2-00:00:00"
	elif [[ $1 == "heavy" ]]; then
		CPU=32
		MEM="128G"
		TIME="7-00:00:00"
	elif [[ $1 == "hic" ]]; then
		CPU=32
		MEM="16G"
		TIME="2-00:00:00"
	elif [[ $1 == "him" ]]; then
		CPU=8
		MEM="128G"
		TIME="2-00:00:00"
	else
		echo "Wrong preset. Pick one from: light, medium, heavy"
		return 1
	fi

	srun \
		--cpus-per-task=$CPU \
		--mem=$MEM \
		--time=$TIME \
		--pty bash
}

# === Evaluate subcommands ===

subcmd=$1

case $subcmd in
	pinfo) shift; pinfo ;;
	cbf) shift; cbf $@ ;;
	sfa) shift; sfa $@ ;;
	eln) shift; eln $@ ;;
	ttmd) shift; ttmd $@ ;;
	sin) shift; sin $@ ;;
	shide) shift; shide $@ ;;
	inter) shift; inter $@ ;;
	*) help >&2; exit 1 ;;
esac
