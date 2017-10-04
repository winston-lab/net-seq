#!/usr/bin/env python
import os
from math import log2

configfile: "config.yaml"

SAMPLES = config["samples"]
name_string = " ".join(SAMPLES)
PASSING = {k:v for (k,v) in SAMPLES.items() if v["pass-qc"] == "pass"}
pass_string = " ".join(PASSING)

controlgroups = config["comparisons"]["libsizenorm"]["controls"]
conditiongroups = config["comparisons"]["libsizenorm"]["conditions"]
controlgroups_si = config["comparisons"]["spikenorm"]["controls"]
conditiongroups_si = config["comparisons"]["spikenorm"]["conditions"]

CATEGORIES = ["genic", "intragenic", "intergenic", "antisense", "convergent", "divergent"]

localrules: all,
            make_stranded_genome, make_stranded_bedgraph, make_stranded_sicounts_bedgraph,
            make_stranded_annotations, make_stranded_genic_anno,
            get_si_pct, cat_si_pct,
            bg_to_bw, melt_matrix, cat_matrices,
            union_bedgraph, union_bedgraph_cond_v_ctrl,
            separate_de_bases, de_bases_to_bed, merge_de_bases_to_clusters,
            cat_cluster_strands,
            map_counts_to_clusters, get_cluster_counts,
            # extract_base_distances,
            separate_de_clusters, de_clusters_to_bed,
            build_genic_annotation, build_convergent_annotation, build_divergent_annotation,
            get_putative_genic, get_putative_intragenic, get_putative_antisense,
            get_putative_intergenic, get_putative_convergent, get_putative_divergent,
            get_category_bed,
            get_peak_sequences,
            get_genic_counts, map_counts_to_genic

rule all:
    input:
        #FastQC
        expand("qual_ctrl/fastqc/raw/{sample}", sample=SAMPLES),
        expand("qual_ctrl/fastqc/cleaned/{sample}/{sample}-clean_fastqc.zip", sample=SAMPLES),
        #datavis
        # expand("datavis/{annotation}/{norm}/tss-{annotation}-{norm}-{strand}-heatmap-bygroup.png", annotation = config["annotations"], norm = ["spikenorm", "libsizenorm"], strand = ["SENSE", "ANTISENSE"]),
        #quality control
        expand("qual_ctrl/{status}/{status}-spikein-plots.png", status=["all", "passing"]),
        expand(expand("qual_ctrl/{{status}}/{condition}-v-{control}-tss-libsizenorm-correlations.png", zip, condition=conditiongroups+["all"], control=controlgroups+["all"]), status = ["all", "passing"]),
        expand(expand("qual_ctrl/{{status}}/{condition}-v-{control}-tss-spikenorm-correlations.png", zip, condition=conditiongroups_si+["all"], control=controlgroups_si+["all"]), status = ["all", "passing"]),
        #call DE bases
        expand("diff_exp/{condition}-v-{control}/{condition}-v-{control}-base-qcplots-libsizenorm.png", zip, condition=conditiongroups, control=controlgroups),
        expand("diff_exp/{condition}-v-{control}/{condition}-v-{control}-base-qcplots-spikenorm.png", zip, condition=conditiongroups_si, control=controlgroups_si),
        # "qual_ctrl/all/all-pca-scree-libsizenorm.png",
        # "qual_ctrl/passing/passing-pca-scree-libsizenorm.png",
        #coverage
        # expand("coverage/{norm}/bw/{sample}-tss-{norm}-{strand}.bw", norm = ["spikenorm", "libsizenorm"], sample=SAMPLES, strand = ["SENSE", "ANTISENSE", "plus", "minus"]),
        #differentially expressed clusters
        # expand(expand("diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-spikenorm-{{direction}}.bed", zip, condition=conditiongroups_si, control=controlgroups_si), direction = ["up", "down"]),
        # expand(expand("diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-libsizenorm-{{direction}}.bed", zip, condition=conditiongroups, control=controlgroups), direction = ["up", "down"]),
        #differential expresion for all genic regions
        # expand("diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-genic-spikenorm.tsv", zip, condition=conditiongroups_si, control=controlgroups_si),
        # expand("diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-genic-libsizenorm.tsv", zip, condition=conditiongroups, control=controlgroups),
        #find intragenic ORFs
        # expand(expand("diff_exp/{condition}-v-{control}/intragenic/intragenic-orfs/{condition}-v-{control}-libsizenorm-{{direction}}-intragenic-orfs.tsv", zip, condition=conditiongroups, control=controlgroups), direction = ["up", "down"]),
        # expand(expand("diff_exp/{condition}-v-{control}/intragenic/intragenic-orfs/{condition}-v-{control}-spikenorm-{{direction}}-intragenic-orfs.tsv", zip, condition=conditiongroups_si, control=controlgroups_si), direction = ["up", "down"]),
        #MEME-ChIP
        # expand(expand("diff_exp/{condition}-v-{control}/{{category}}/{condition}-v-{control}-spikenorm-{{direction}}-{{category}}-motifs/index.html", zip, condition=conditiongroups_si, control=controlgroups_si), direction = ["up", "down"], category = CATEGORIES),
        # expand(expand("diff_exp/{condition}-v-{control}/{{category}}/{condition}-v-{control}-libsizenorm-{{direction}}-{{category}}-motifs/index.html", zip, condition=conditiongroups, control=controlgroups), direction = ["up", "down"], category = CATEGORIES),
        # expand(expand("diff_exp/{condition}-v-{control}/{{type}}/{{type}}-v-genic/{condition}-v-{control}-{{type}}-v-genic-spikenorm.tsv", zip, condition=conditiongroups_si, control=controlgroups_si), type=["antisense", "convergent", "divergent", "intragenic"]),
        # expand(expand("diff_exp/{condition}-v-{control}/{{type}}/{{type}}-v-genic/{condition}-v-{control}-{{type}}-v-genic-libsizenorm.tsv", zip, condition=conditiongroups, control=controlgroups), type=["antisense", "convergent", "divergent", "intragenic"]),
        # intrafreq
        # expand(expand("diff_exp/{condition}-v-{control}/intragenic/intrafreq/{condition}-v-{control}-intragenic-libsizenorm-{{direction}}-freqperORF.png", zip, condition=conditiongroups, control=controlgroups), direction = ["up", "down"]),
        # expand(expand("diff_exp/{condition}-v-{control}/intragenic/intrafreq/{condition}-v-{control}-intragenic-spikenorm-{{direction}}-freqperORF.png", zip, condition=conditiongroups_si, control=controlgroups_si), direction = ["up", "down"]),

rule fastqc_raw:
    input:
        lambda wildcards: SAMPLES[wildcards.sample]["fastq"]
    output:
        "qual_ctrl/fastqc/raw/{sample}"
    threads: config["threads"]
    log: "logs/fastqc/raw/fastqc-raw-{sample}.log"
    shell: """
        (mkdir -p {output}) &> {log}
        (fastqc -o {output} --noextract -t {threads} {input}) &>> {log}
        """

#in this order: remove adapter, remove 3' molecular barcode, do NextSeq quality trimming
#reads shorter than 18 are thrown out, as the first 6 bases are the molecular barcode and 12-mer is around the theoretical minimum length to map uniquely to the combined Sc+Sp genome (~26 Mb)
rule remove_adapter:
    input:
        lambda wildcards: SAMPLES[wildcards.sample]["fastq"]
    output:
        temp("fastq/cleaned/{sample}-noadapter.fastq.gz")
    params:
        adapter = config["cutadapt"]["adapter"],
    log: "logs/remove_adapter/remove_adapter-{sample}.log"
    shell: """
        (cutadapt -a {params.adapter} -m 24 -o {output} {input}) &> {log}
        """

rule remove_3p_barcode_and_qual_trim:
    input:
        "fastq/cleaned/{sample}-noadapter.fastq.gz"
    output:
        temp("fastq/cleaned/{sample}-trim.fastq")
    params:
        trim_qual = config["cutadapt"]["trim_qual"]
    log: "logs/remove_3p_bc_and_trim/cutadapt-{sample}.log"
    shell: """
        (cutadapt -u -6 --nextseq-trim={params.trim_qual} -m 18 -o {output} {input}) &> {log}
        """

rule remove_molec_barcode:
    input:
        "fastq/cleaned/{sample}-trim.fastq"
    output:
        fq = "fastq/cleaned/{sample}-clean.fastq.gz",
        barcodes = "qual_ctrl/molec_barcode/barcodes-{sample}.tsv",
        ligation = "qual_ctrl/molec_barcode/ligation-{sample}.tsv"
    threads: config["threads"]
    log: "logs/remove_molec_barcode/removeMBC-{sample}.log"
    shell: """
        (python scripts/extractMolecularBarcode.py {input} fastq/cleaned/{wildcards.sample}-clean.fastq {output.barcodes} {output.ligation}) &> {log}
        (pigz -f fastq/cleaned/{wildcards.sample}-clean.fastq) &>> {log}
        """

rule fastqc_cleaned:
    input:
        "fastq/cleaned/{sample}-clean.fastq.gz"
    output:
        html = "qual_ctrl/fastqc/cleaned/{sample}/{sample}-clean_fastqc.html",
        folder  = "qual_ctrl/fastqc/cleaned/{sample}/{sample}-clean_fastqc.zip"
    threads : config["threads"]
    log: "logs/fastqc/cleaned/fastqc-cleaned-{sample}.log"
    shell: """
        (mkdir -p qual_ctrl/fastqc/cleaned/{wildcards.sample}) &> {log}
        (fastqc -o qual_ctrl/fastqc/cleaned/{wildcards.sample} --noextract -t {threads} {input}) &>> {log}
        """

#align to combined genome with Tophat2, WITHOUT reference transcriptome (i.e., the -G gff)
#(because we don't always have a reference gff and it doesn't make much difference)
rule bowtie2_build:
    input:
        fasta = config["combinedgenome"]["fasta"]
    output:
        expand("../genome/bowtie2_indexes/{basename}.{num}.bt2", basename=config["combinedgenome"]["name"], num=[1,2,3,4]),
        expand("../genome/bowtie2_indexes/{basename}.rev.{num}.bt2", basename=config["combinedgenome"]["name"], num=[1,2])
    params:
        name = config["combinedgenome"]["name"]
    log: "logs/bowtie2_build.log"
    shell: """
        (bowtie2-build {input.fasta} ../genome/bowtie2_indexes/{params.name}) &> {log}
        """

rule align:
    input:
        expand("../genome/bowtie2_indexes/{basename}.{num}.bt2", basename=config["combinedgenome"]["name"], num = [1,2,3,4]),
        expand("../genome/bowtie2_indexes/{basename}.rev.{num}.bt2", basename=config["combinedgenome"]["name"], num=[1,2]),
        fastq = "fastq/cleaned/{sample}-clean.fastq.gz"
    output:
        "alignment/{sample}/accepted_hits.bam"
    params:
        basename = config["combinedgenome"]["name"],
        read_mismatches = config["tophat2"]["read-mismatches"],
        read_gap_length = config["tophat2"]["read-gap-length"],
        read_edit_dist = config["tophat2"]["read-edit-dist"],
        min_anchor_length = config["tophat2"]["min-anchor-length"],
        splice_mismatches = config["tophat2"]["splice-mismatches"],
        min_intron_length = config["tophat2"]["min-intron-length"],
        max_intron_length = config["tophat2"]["max-intron-length"],
        max_insertion_length = config["tophat2"]["max-insertion-length"],
        max_deletion_length = config["tophat2"]["max-deletion-length"],
        max_multihits = config["tophat2"]["max-multihits"],
        segment_mismatches = config["tophat2"]["segment-mismatches"],
        segment_length = config["tophat2"]["segment-length"],
        min_coverage_intron = config["tophat2"]["min-coverage-intron"],
        max_coverage_intron = config["tophat2"]["max-coverage-intron"],
        min_segment_intron = config["tophat2"]["min-segment-intron"],
        max_segment_intron = config["tophat2"]["max-segment-intron"],
    conda:
        "envs/tophat2.yaml"
    threads : config["threads"]
    log: "logs/align/align-{sample}.log"
    shell:
        """
        (tophat2 --read-mismatches {params.read_mismatches} --read-gap-length {params.read_gap_length} --read-edit-dist {params.read_edit_dist} -o alignment/{wildcards.sample} --min-anchor-length {params.min_anchor_length} --splice-mismatches {params.splice_mismatches} --min-intron-length {params.min_intron_length} --max-intron-length {params.max_intron_length} --max-insertion-length {params.max_insertion_length} --max-deletion-length {params.max_deletion_length} --num-threads {threads} --max-multihits {params.max_multihits} --library-type fr-firststrand --segment-mismatches {params.segment_mismatches} --no-coverage-search --segment-length {params.segment_length} --min-coverage-intron {params.min_coverage_intron} --max-coverage-intron {params.max_coverage_intron} --min-segment-intron {params.min_segment_intron} --max-segment-intron {params.max_segment_intron} --b2-sensitive ../genome/bowtie2_indexes/{params.basename} {input.fastq}) &> {log}
        """

rule select_unique_mappers:
    input:
        "alignment/{sample}/accepted_hits.bam"
    output:
        temp("alignment/{sample}-unique.bam")
    threads: config["threads"]
    log: "logs/select_unique_mappers/select_unique_mappers-{sample}.log"
    shell: """
        (samtools view -b -h -q 50 -@ {threads} {input} | samtools sort -@ {threads} - > {output}) &> {log}
        """

rule remove_PCR_duplicates:
    input:
        "alignment/{sample}-unique.bam"
    output:
        "alignment/{sample}-noPCRdup.bam"
    log: "logs/remove_PCR_duplicates/removePCRduplicates-{sample}.log"
    shell: """
        (python scripts/removePCRdupsFromBAM.py {input} {output}) &> {log}
        """

rule get_coverage:
    input:
        "alignment/{sample}-noPCRdup.bam"
    output:
        SIplmin = "coverage/counts/spikein/{sample}-tss-SI-counts-plmin.bedgraph",
        SIpl = "coverage/counts/spikein/{sample}-tss-SI-counts-plus.bedgraph",
        SImin = "coverage/counts/spikein/{sample}-tss-SI-counts-minus.bedgraph",
        plmin = "coverage/counts/{sample}-tss-counts-plmin.bedgraph",
        plus = "coverage/counts/{sample}-tss-counts-plus.bedgraph",
        minus = "coverage/counts/{sample}-tss-counts-minus.bedgraph"
    params:
        exp_prefix = config["combinedgenome"]["experimental_prefix"],
        si_prefix = config["combinedgenome"]["spikein_prefix"]
    log: "logs/get_coverage/get_coverage-{sample}.log"
    shell: """
        (genomeCoverageBed -bga -5 -ibam {input} | grep {params.si_prefix} | sed 's/{params.si_prefix}//g' | sort -k1,1 -k2,2n > {output.SIplmin}) &> {log}
        (genomeCoverageBed -bga -5 -strand + -ibam {input} | grep {params.si_prefix} | sed 's/{params.si_prefix}//g' | sort -k1,1 -k2,2n > {output.SIpl}) &>> {log}
        (genomeCoverageBed -bga -5 -strand - -ibam {input} | grep {params.si_prefix} | sed 's/{params.si_prefix}//g' | sort -k1,1 -k2,2n > {output.SImin}) &>> {log}
        (genomeCoverageBed -bga -5 -ibam {input} | grep {params.exp_prefix} | sed 's/{params.exp_prefix}//g' | sort -k1,1 -k2,2n > {output.plmin}) &>> {log}
        (genomeCoverageBed -bga -5 -strand + -ibam {input} | grep {params.exp_prefix} | sed 's/{params.exp_prefix}//g' | sort -k1,1 -k2,2n > {output.plus}) &>> {log}
        (genomeCoverageBed -bga -5 -strand - -ibam {input} | grep {params.exp_prefix} | sed 's/{params.exp_prefix}//g' | sort -k1,1 -k2,2n > {output.minus}) &>> {log}
        """

#NOTE: should we scale the spikenorm values by the spike-in pct? right now the values are rpms, but this will be 10x the rpm values
rule normalize:
    input:
        plus = "coverage/counts/{sample}-tss-counts-plus.bedgraph",
        minus = "coverage/counts/{sample}-tss-counts-minus.bedgraph",
        plmin = "coverage/counts/{sample}-tss-counts-plmin.bedgraph",
        SIplmin = "coverage/counts/spikein/{sample}-tss-SI-counts-plmin.bedgraph"
    output:
        spikePlus = "coverage/spikenorm/{sample}-tss-spikenorm-plus.bedgraph",
        spikeMinus = "coverage/spikenorm/{sample}-tss-spikenorm-minus.bedgraph",
        libnormPlus = "coverage/libsizenorm/{sample}-tss-libsizenorm-plus.bedgraph",
        libnormMinus = "coverage/libsizenorm/{sample}-tss-libsizenorm-minus.bedgraph"
    log: "logs/normalize/normalize-{sample}.log"
    shell: """
        (scripts/libsizenorm.awk {input.SIplmin} {input.plus} > {output.spikePlus}) &> {log}
        (scripts/libsizenorm.awk {input.SIplmin} {input.minus} > {output.spikeMinus}) &>> {log}
        (scripts/libsizenorm.awk {input.plmin} {input.plus} > {output.libnormPlus}) &>> {log}
        (scripts/libsizenorm.awk {input.plmin} {input.minus} > {output.libnormMinus}) &>> {log}
        """

rule get_si_pct:
    input:
        plmin = "coverage/counts/{sample}-tss-counts-plmin.bedgraph",
        SIplmin = "coverage/counts/spikein/{sample}-tss-SI-counts-plmin.bedgraph"
    output:
        temp("qual_ctrl/all/{sample}-spikeincounts.tsv")
    params:
        group = lambda wildcards: SAMPLES[wildcards.sample]["group"]
    log: "logs/get_si_pct/get_si_pct-{sample}.log"
    shell: """
        (echo {wildcards.sample} {params.group} $(awk 'BEGIN{{FS=OFS="\t"; ex=0; si=0}}{{if(NR==FNR){{si+=$4}} else{{ex+=$4}}}} END{{print ex+si, ex, si}}' {input.SIplmin} {input.plmin}) > {output}) &> {log}
        """

rule cat_si_pct:
    input:
        expand("qual_ctrl/all/{sample}-spikeincounts.tsv", sample=SAMPLES)
    output:
        "qual_ctrl/all/spikein-counts.tsv"
    log: "logs/cat_si_pct.log"
    shell: """
        (cat {input} > {output}) &> {log}
        """

rule plot_si_pct:
    input:
        "qual_ctrl/all/spikein-counts.tsv"
    output:
        plot = "qual_ctrl/{status}/{status}-spikein-plots.png",
        stats = "qual_ctrl/{status}/{status}-spikein-stats.tsv"
    params:
        samplelist = lambda wildcards : list({k:v for (k,v) in SAMPLES.items() if v["spikein"]=="y"}.keys()) if wildcards.status=="all" else list({k:v for (k,v) in PASSING.items() if v["spikein"]=="y"}.keys()),
        conditions = config["comparisons"]["spikenorm"]["conditions"],
        controls = config["comparisons"]["spikenorm"]["controls"],
    script: "scripts/plotsipct.R"

#make 'stranded' genome for datavis purposes
rule make_stranded_genome:
    input:
        config["genome"]["chrsizes"]
    output:
        os.path.splitext(config["genome"]["chrsizes"])[0] + "-STRANDED.tsv"
    log: "logs/make_stranded_genome.log"
    shell: """
        (awk 'BEGIN{{FS=OFS="\t"}}{{print $1"-plus", $2}}{{print $1"-minus", $2}}' {input} > {output}) &> {log}
        """

rule make_stranded_bedgraph:
    input:
        plus = "coverage/{norm}/{sample}-tss-{norm}-plus.bedgraph",
        minus = "coverage/{norm}/{sample}-tss-{norm}-minus.bedgraph"
    output:
        sense = "coverage/{norm}/{sample}-tss-{norm}-SENSE.bedgraph",
        antisense = "coverage/{norm}/{sample}-tss-{norm}-ANTISENSE.bedgraph"
    log : "logs/make_stranded_bedgraph/make_stranded_bedgraph-{sample}-{norm}.log"
    shell: """
        (bash scripts/makeStrandedBedgraph.sh {input.plus} {input.minus} > {output.sense}) &> {log}
        (bash scripts/makeStrandedBedgraph.sh {input.minus} {input.plus} > {output.antisense}) &>> {log}
        """

rule make_stranded_sicounts_bedgraph:
    input:
        plus = "coverage/counts/spikein/{sample}-tss-SI-counts-plus.bedgraph",
        minus = "coverage/counts/spikein/{sample}-tss-SI-counts-minus.bedgraph"
    output:
        sense = "coverage/counts/spikein/{sample}-tss-SI-counts-SENSE.bedgraph"
    log: "logs/make_stranded_sicounts_bedgraph/make_stranded_sicounts_bedgraph-{sample}.log"
    shell: """
        (bash scripts/makeStrandedBedgraph.sh {input.plus} {input.minus} > {output.sense}) &> {log}
        """

rule make_stranded_annotations:
    input:
        lambda wildcards : config["annotations"][wildcards.annotation]["path"]
    output:
        "../genome/annotations/stranded/{annotation}-STRANDED.bed"
    log : "logs/make_stranded_annotations/make_stranded_annotations-{annotation}.log"
    shell: """
        (bash scripts/makeStrandedBed.sh {input} > {output}) &> {log}
        """

rule bg_to_bw:
    input:
        bedgraph = "coverage/{norm}/{sample}-tss-{norm}-{strand}.bedgraph",
        chrsizes = lambda wildcards: config["genome"]["chrsizes"] if wildcards.strand=="plus" or "minus" else os.path.splitext(config["genome"]["chrsizes"])[0] + "-STRANDED.tsv"
    output:
        "coverage/{norm}/bw/{sample}-tss-{norm}-{strand}.bw",
    log : "logs/bg_to_bw/bg_to_bw-{sample}-{norm}-{strand}.log"
    shell: """
        (bedGraphToBigWig {input.bedgraph} {input.chrsizes} {output}) &> {log}
        """

rule deeptools_matrix:
    input:
        annotation = "../genome/annotations/stranded/{annotation}-STRANDED.bed",
        bw = "coverage/{norm}/bw/{sample}-tss-{norm}-{strand}.bw"
    output:
        dtfile = temp("datavis/{annotation}/{norm}/{annotation}-{sample}-{norm}-{strand}.mat.gz"),
        matrix = "datavis/{annotation}/{norm}/{annotation}-{sample}-{norm}-{strand}.tsv.gz"
    params:
        refpoint = lambda wildcards: config["annotations"][wildcards.annotation]["refpoint"],
        upstream = lambda wildcards: config["annotations"][wildcards.annotation]["upstream"],
        dnstream = lambda wildcards: config["annotations"][wildcards.annotation]["dnstream"],
        binsize = lambda wildcards: config["annotations"][wildcards.annotation]["binsize"],
        sort = lambda wildcards: config["annotations"][wildcards.annotation]["sort"],
        sortusing = lambda wildcards: config["annotations"][wildcards.annotation]["sortby"],
        binstat = lambda wildcards: config["annotations"][wildcards.annotation]["binstat"]
    threads : config["threads"]
    log: "logs/deeptools/computeMatrix-{annotation}-{sample}-{norm}-{strand}.log"
    #shell: """
    #    (computeMatrix reference-point -R {input.annotation} -S {input.bw} --referencePoint {params.refpoint} -out {output.dtfile} --outFileNameMatrix {output.matrix} -b {params.upstream} -a {params.dnstream} --nanAfterEnd --binSize {params.binsize} --sortRegions {params.sort} --sortUsing {params.sortusing} --averageTypeBins {params.binstat} -p {threads}) &> {log}
    #    """
    shell: """
        (computeMatrix reference-point -R {input.annotation} -S {input.bw} --referencePoint {params.refpoint} -out {output.dtfile} --outFileNameMatrix {output.matrix} -b {params.upstream} -a {params.dnstream} --binSize {params.binsize} --sortRegions {params.sort} --sortUsing {params.sortusing} --averageTypeBins {params.binstat} -p {threads}) &> {log}
        (pigz -f datavis/{wildcards.annotation}/{wildcards.norm}/{wildcards.annotation}-{wildcards.sample}-{wildcards.norm}-{wildcards.strand}.tsv) &>> {log}
        """

rule melt_matrix:
    input:
        matrix = "datavis/{annotation}/{norm}/{annotation}-{sample}-{norm}-{strand}.tsv.gz"
    output:
        temp("datavis/{annotation}/{norm}/{annotation}-{sample}-{norm}-{strand}-melted.tsv.gz")
    params:
        name = lambda wildcards : wildcards.sample,
        group = lambda wildcards : SAMPLES[wildcards.sample]["group"],
        binsize = lambda wildcards : config["annotations"][wildcards.annotation]["binsize"],
        upstream = lambda wildcards : config["annotations"][wildcards.annotation]["upstream"],
        dnstream = lambda wildcards : config["annotations"][wildcards.annotation]["dnstream"]
    script:
        "scripts/melt_matrix.R"

rule cat_matrices:
    input:
        expand("datavis/{{annotation}}/{{norm}}/{{annotation}}-{sample}-{{norm}}-{{strand}}-melted.tsv.gz", sample=SAMPLES)
    output:
        "datavis/{annotation}/{norm}/allsamples-{annotation}-{norm}-{strand}.tsv.gz"
    log: "logs/cat_matrices/cat_matrices-{annotation}-{norm}-{strand}.log"
    shell: """
        (cat {input} > {output}) &> {log}
        """

rule r_datavis:
    input:
        matrix = "datavis/{annotation}/{norm}/allsamples-{annotation}-{norm}-{strand}.tsv.gz"
    output:
        heatmap_sample = "datavis/{annotation}/{norm}/tss-{annotation}-{norm}-{strand}-heatmap-bysample.png",
        heatmap_group = "datavis/{annotation}/{norm}/tss-{annotation}-{norm}-{strand}-heatmap-bygroup.png",
    params:
        binsize = lambda wildcards : config["annotations"][wildcards.annotation]["binsize"],
        upstream = lambda wildcards : config["annotations"][wildcards.annotation]["upstream"],
        dnstream = lambda wildcards : config["annotations"][wildcards.annotation]["dnstream"],
        pct_cutoff = lambda wildcards : config["annotations"][wildcards.annotation]["pct_cutoff"],
        heatmap_cmap = lambda wildcards : config["annotations"][wildcards.annotation]["heatmap_colormap"],
        #metagene_palette = lambda wildcards : config["annotations"][wildcards.annotation]["metagene_palette"],
        #avg_heatmap_cmap = lambda wildcards : config["annotations"][wildcards.annotation]["avg_heatmap_cmap"],
        refpointlabel = lambda wildcards : config["annotations"][wildcards.annotation]["refpointlabel"],
        ylabel = lambda wildcards : config["annotations"][wildcards.annotation]["ylabel"]
    script:
        "scripts/plotHeatmaps.R"

rule union_bedgraph:
    input:
        exp = expand("coverage/{{norm}}/{sample}-tss-{{norm}}-SENSE.bedgraph", sample=SAMPLES)
    output:
        exp = "coverage/{norm}/union-bedgraph-allsamples-{norm}.tsv.gz",
    params:
    log: "logs/union_bedgraph-{norm}.log"
    shell: """
        (bedtools unionbedg -i {input.exp} -header -names {name_string} | bash scripts/cleanUnionbedg.sh | pigz > {output.exp}) &> {log}
        """

rule union_bedgraph_si_counts:
    input:
        si = expand("coverage/counts/spikein/{sample}-tss-SI-counts-SENSE.bedgraph", sample=SAMPLES),
    output:
        si = "coverage/counts/spikein/union-bedgraph-allsamples-si-counts.tsv.gz",
    params:
    log: "logs/union_bedgraph_si_counts.log"
    shell: """
        (bedtools unionbedg -i {input.si} -header -names {name_string} | bash scripts/cleanUnionbedg.sh | pigz > {output.si}) &> {log}
        """

def plotcorrsamples(wildcards):
    dd = SAMPLES if wildcards.status=="all" else PASSING
    if wildcards.condition=="all":
        if wildcards.norm=="libsizenorm": #condition==all,norm==lib
            return list(dd.keys())
        else: #condition==all,norm==spike
            return list({k:v for (k,v) in dd.items() if v["spikein"]=="y"}.keys())
    elif wildcards.norm=="libsizenorm": #condition!=all;norm==lib
        return list({k:v for (k,v) in dd.items() if v["group"]==wildcards.control or v["group"]==wildcards.condition}.keys())
    else: #condition!=all;norm==spike
        return list({k:v for (k,v) in dd.items() if (v["group"]==wildcards.control or v["group"]==wildcards.condition) and v["spikein"]=="y"}.keys())

rule plotcorrelations:
    input:
        "coverage/{norm}/union-bedgraph-allsamples-{norm}.tsv.gz"
    output:
        "qual_ctrl/{status}/{condition}-v-{control}-tss-{norm}-correlations.png"
    params:
        pcount = 0.1,
        samplelist = plotcorrsamples
    script:
        "scripts/plotcorr.R"

#NOTE: need to check whether the median of ratios normalization is okay (e.g. for spt6 samples)
rule call_de_bases:
    input:
        counts = "coverage/counts/union-bedgraph-allsamples-counts.tsv.gz",
        sicounts = "coverage/counts/spikein/union-bedgraph-allsamples-si-counts.tsv.gz"
    params:
        samples = lambda wildcards : list({k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)}.keys()),
        groups = lambda wildcards : [PASSING[x]["group"] for x in {k:v for (k,v) in PASSING.items() if (v["group"]==wildcards.control or v["group"]==wildcards.condition)}],
        alpha = config["deseq"]["fdr"],
    output:
        results = "diff_exp/{condition}-v-{control}/{condition}-v-{control}-base-results-{norm}.tsv",
        #need to write out norm counts here or just in the total qc?
        normcounts = "diff_exp/{condition}-v-{control}/{condition}-v-{control}-counts-sfnorm-{norm}.tsv",
        rldcounts = "diff_exp/{condition}-v-{control}/{condition}-v-{control}-counts-rlog-{norm}.tsv",
        qcplots = "diff_exp/{condition}-v-{control}/{condition}-v-{control}-base-qcplots-{norm}.png"
    script:
        "scripts/call_de_bases2.R"

rule separate_de_bases:
    input:
        "diff_exp/{condition}-v-{control}/de_bases/{condition}-v-{control}-de-bases-{norm}.tsv"
    output:
        up = "diff_exp/{condition}-v-{control}/de_bases/{condition}-v-{control}-de-bases-{norm}-up.tsv",
        down = "diff_exp/{condition}-v-{control}/de_bases/{condition}-v-{control}-de-bases-{norm}-down.tsv"
    log: "logs/separate_de_bases/separate_de_bases-{condition}-v-{control}-{norm}.log"
    shell: """
        (awk 'BEGIN{{FS=OFS="\t"}} $3>=0 {{print $0}}' {input} > {output.up}) &> {log}
        (awk 'BEGIN{{FS=OFS="\t"}} $3<0 {{print $0}}' {input} > {output.down}) &>> {log}
        """

rule de_bases_to_bed:
    input:
        up = "diff_exp/{condition}-v-{control}/de_bases/{condition}-v-{control}-de-bases-{norm}-up.tsv",
        down = "diff_exp/{condition}-v-{control}/de_bases/{condition}-v-{control}-de-bases-{norm}-down.tsv"
    output:
        up = "diff_exp/{condition}-v-{control}/de_bases/{condition}-v-{control}-de-bases-{norm}-up.bed",
        down = "diff_exp/{condition}-v-{control}/de_bases/{condition}-v-{control}-de-bases-{norm}-down.bed"
    log: "logs/de_bases_to_bed/de_bases_to_bed-{condition}-v-{control}-{norm}.log"
    shell: """
        (tail -n +2 {input.up} | awk 'BEGIN{{FS=OFS="\t"}}{{print $1, -log($7)/log(10)}}' | awk -F '[-\t]' 'BEGIN{{OFS="\t"}} $2=="plus"{{print $1"-"$2, $3, $4, "up_"NR, $5, "+"}} $2=="minus"{{print $1"-"$2, $3, $4, "up_"NR, $5, "-"}}' | LC_COLLATE=C sort -k1,1 -k2,2n > {output.up}) &> {log}
        (tail -n +2 {input.down} | awk 'BEGIN{{FS=OFS="\t"}}{{print $1, -log($7)/log(10)}}'| awk -F '[-\t]' 'BEGIN{{OFS="\t"}} $2=="plus"{{print $1"-"$2, $3, $4, "down_"NR, $5, "+"}} $2=="minus"{{print $1"-"$2, $3, $4, "down_"NR, $5, "-"}}' | LC_COLLATE=C sort -k1,1 -k2,2n > {output.down}) &>> {log}
        """

#TODO: rewrite this to extract base and cluster distances
#rule extract_base_distances:
#    input:
#        up = "diff_exp/de_bases/de-bases-{norm}-up.bed",
#        down = "diff_exp/de_bases/de-bases-{norm}-down.bed"
#    output:
#        "diff_exp/de_bases/base-distances-{norm}.tsv"
#    shell: """
#        bedtools closest -s -d -io -t first -a {input.up} -b {input.up} | cut -f13 > diff_exp/.{wildcards.norm}-basedistances-up.temp
#        bedtools closest -s -d -io -t first -a {input.down} -b {input.down} | cut -f13 > diff_exp/.{wildcards.norm}-basedistances-down.temp
#        cat diff_exp/.{wildcards.norm}-basedistances-up.temp diff_exp/.{wildcards.norm}-basedistances-down.temp > {output}
#        rm diff_exp/.{wildcards.norm}*.temp
#        """

#rule vis_base_distances

rule merge_de_bases_to_clusters:
    input:
        "diff_exp/{condition}-v-{control}/de_bases/{condition}-v-{control}-de-bases-{norm}-{direction}.bed"
    output:
        "diff_exp/{condition}-v-{control}/de_bases/allclusters/{condition}-v-{control}-allclusters-{norm}-{direction}.bed"
    params:
        mergedist = config["cluster-merge-distance"]
    log: "logs/merge_de_bases_to_clusters/merge_de_bases_to_clusters-{condition}-v-{control}-{norm}-{direction}.log"
    shell: """
        (bedtools merge -s -d {params.mergedist} -i {input} | LC_COLLATE=C sort -k1,1 -k2,2n > {output}) &> {log}
        """

rule cat_cluster_strands:
    input:
        expand("diff_exp/{{condition}}-v-{{control}}/de_bases/allclusters/{{condition}}-v-{{control}}-allclusters-{{norm}}-{direction}.bed", direction = ["up", "down"])
    output:
        "diff_exp/{condition}-v-{control}/de_bases/allclusters/{condition}-v-{control}-allclusters-{norm}-combined.bed"
    log: "logs/cat_cluster_strands/cat_cluster_strands-{condition}-v-{control}-{norm}.log"
    shell: """
        (cat {input} | LC_COLLATE=C sort -k1,1 -k2,2n > {output}) &> {log}
        """

rule make_stranded_genic_anno:
    input:
        os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "genic-regions.bed",
    output:
        os.path.dirname(config["genome"]["transcripts"]) + "/stranded/" + config["combinedgenome"]["experimental_prefix"] + "genic-regions-STRANDED.bed",
    log : "logs/make_stranded_genic_anno.log"
    shell: """
        (bash scripts/makeStrandedBed.sh {input} | LC_COLLATE=C sort -k1,1 -k2,2n > {output}) &> {log}
        """

rule map_counts_to_genic:
    input:
        bed = os.path.dirname(config["genome"]["transcripts"]) + "/stranded/" + config["combinedgenome"]["experimental_prefix"] + "genic-regions-STRANDED.bed",
        bg = "coverage/counts/{sample}-tss-counts-SENSE.bedgraph"
    output:
        temp("diff_exp/{condition}-v-{control}/all_genic/{sample}-allgenic-{norm}.tsv")
    log: "logs/map_counts_to_genic/map_counts_to_genic-{condition}-v-{control}-{sample}-{norm}.log"
    shell: """
        (bedtools map -a {input.bed} -b {input.bg} -c 4 -o sum | awk 'BEGIN{{FS=OFS="\t"}}{{print $4, $7}}' > {output}) &> {log}
        """

rule get_genic_counts:
    input:
        lambda wildcards : ["diff_exp/" + wildcards.condition + "-v-" + wildcards.control + "/all_genic/" + x + "-allgenic-" + wildcards.norm + ".tsv" for x in list({k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)})]
    output:
        "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-{norm}-genic-counts.tsv"
    log: "logs/get_genic_counts/get_genic_counts-{condition}-v-{control}-{norm}.log"
    shell: """
        (bash scripts/recursivejoin.sh {input} > {output}) &> {log}
        """

rule call_allgenic_spikenorm:
    input:
        clustercounts= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-spikenorm-genic-counts.tsv",
        libcounts = "coverage/counts/spikein/union-bedgraph-si-{condition}-v-{control}.txt"
    params:
        alpha = config["deseq"]["fdr"],
        lfcThreshold = log2(config["deseq"]["fold-change-threshold"]),
        samples = lambda wildcards : list({k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)}.keys()),
        samplegroups = lambda wildcards : [PASSING[x]["group"] for x in {k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)}]
    output:
        corrplot= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-allgenic-pairwise-correlation-spikenorm.png",
        count_heatmap= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-allgenic-heatmap-spikenorm.png",
        dist_heatmap= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-allgenic-sample-dists-spikenorm.png",
        pca= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-allgenic-pca-spikenorm.png",
        scree= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-allgenic-pca-scree-spikenorm.png",
        all_path = "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-genic-spikenorm.tsv",
        de_path = "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-DEgenic-spikenorm.tsv",
        unch_path = "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-nonDEgenic-spikenorm.tsv",
    script:
        "scripts/call_de_clusters.R"

rule call_allgenic_libsizenorm:
    input:
        clustercounts= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-libsizenorm-genic-counts.tsv",
        libcounts = "coverage/counts/union-bedgraph-{condition}-v-{control}.txt"
    params:
        alpha = config["deseq"]["fdr"],
        lfcThreshold = log2(config["deseq"]["fold-change-threshold"]),
        samples = lambda wildcards : list({k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)}.keys()),
        samplegroups = lambda wildcards : [PASSING[x]["group"] for x in {k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)}]
    output:
        corrplot= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-allgenic-pairwise-correlation-libsizenorm.png",
        count_heatmap= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-allgenic-heatmap-libsizenorm.png",
        dist_heatmap= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-allgenic-sample-dists-libsizenorm.png",
        pca= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-allgenic-pca-libsizenorm.png",
        scree= "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-allgenic-pca-scree-libsizenorm.png",
        all_path = "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-genic-libsizenorm.tsv",
        de_path = "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-DEgenic-libsizenorm.tsv",
        unch_path = "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-nonDEgenic-libsizenorm.tsv",
    script:
        "scripts/call_de_clusters.R"

rule map_counts_to_clusters:
    input:
        bed = "diff_exp/{condition}-v-{control}/de_bases/allclusters/{condition}-v-{control}-allclusters-{norm}-combined.bed",
        bg = "coverage/counts/{sample}-tss-counts-SENSE.bedgraph"
    output:
        temp("diff_exp/{condition}-v-{control}/de_clusters/{sample}-allclusters-{norm}.tsv")
    log: "logs/map_counts_to_clusters/map_counts_to_clusters-{condition}-v-{control}-{sample}-{norm}.log"
    shell: """
        (bedtools map -a {input.bed} -b {input.bg} -c 4 -o sum | awk 'BEGIN{{FS=OFS="\t"}}{{print $1"-"$2"-"$3, $5}}' &> {output}) &> {log}
        """

rule get_cluster_counts:
    input:
        lambda wildcards : ["diff_exp/" + wildcards.condition + "-v-" + wildcards.control + "/de_clusters/" + x + "-allclusters-" + wildcards.norm + ".tsv" for x in list({k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)})]
    output:
        "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-{norm}-cluster-counts.tsv"
    log: "logs/get_cluster_counts/get_cluster_counts-{condition}-v-{control}-{norm}.log"
    shell: """
        (bash scripts/recursivejoin.sh {input} > {output}) &> {log}
        """

rule call_de_clusters_spikenorm:
    input:
        clustercounts= "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-spikenorm-cluster-counts.tsv",
        libcounts = "coverage/counts/spikein/union-bedgraph-si-{condition}-v-{control}.txt"
    params:
        alpha = config["deseq"]["fdr"],
        lfcThreshold = log2(config["deseq"]["fold-change-threshold"]),
        samples = lambda wildcards : list({k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)}.keys()),
        samplegroups = lambda wildcards : [PASSING[x]["group"] for x in {k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)}]
    output:
        corrplot= "qual_ctrl/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-pairwise-correlation-spikenorm.png",
        count_heatmap= "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-heatmap-spikenorm.png",
        dist_heatmap= "qual_ctrl/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-sample-dists-spikenorm.png",
        pca= "qual_ctrl/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-pca-spikenorm.png",
        scree= "qual_ctrl/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-pca-scree-spikenorm.png",
        all_path = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-all-clusters-spikenorm.tsv",
        de_path = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-spikenorm.tsv",
        unch_path = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-unchanged-clusters-spikenorm.tsv",
    script:
        "scripts/call_de_clusters.R"

rule call_de_clusters_libsizenorm:
    input:
        clustercounts= "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-libsizenorm-cluster-counts.tsv",
        libcounts = "coverage/counts/union-bedgraph-{condition}-v-{control}.txt"
    params:
        alpha = config["deseq"]["fdr"],
        lfcThreshold = log2(config["deseq"]["fold-change-threshold"]),
        samples = lambda wildcards : list({k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)}.keys()),
        samplegroups = lambda wildcards : [PASSING[x]["group"] for x in {k:v for (k,v) in PASSING.items() if (v["group"]== wildcards.control or v["group"]==wildcards.condition)}]
    output:
        corrplot= "qual_ctrl/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-pairwise-correlation-libsizenorm.png",
        count_heatmap= "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-heatmap-libsizenorm.png",
        dist_heatmap= "qual_ctrl/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-sample-dists-libsizenorm.png",
        pca= "qual_ctrl/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-pca-libsizenorm.png",
        scree= "qual_ctrl/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-pca-scree-libsizenorm.png",
        all_path = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-all-clusters-libsizenorm.tsv",
        de_path = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-libsizenorm.tsv",
        unch_path = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-unchanged-clusters-libsizenorm.tsv",
    script:
        "scripts/call_de_clusters.R"

rule separate_de_clusters:
    input:
        "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}.tsv"
    output:
        up = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-up.tsv",
        down = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-down.tsv"
    log: "logs/separate_de_clusters/separate_de_clusters-{condition}-v-{control}-{norm}.log"
    shell: """
        (awk 'BEGIN{{FS=OFS="\t"}} $3>=0 {{print $0}}' {input} > {output.up}) &> {log}
        (awk 'BEGIN{{FS=OFS="\t"}} $3<0 {{print $0}}' {input} > {output.down}) &>> {log}
        """

rule de_clusters_to_bed:
    input:
        up = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-up.tsv",
        down = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-down.tsv"
    output:
        up = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-up.bed",
        down= "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-down.bed"
    log: "logs/de_clusters_to_bed/de_clusters_to_bed-{condition}-v-{control}-{norm}.log"
    shell: """
        (tail -n +2 {input.up} | awk 'BEGIN{{FS=OFS="\t"}}{{print $1, $3":"(-log($7)/log(10))}}' | awk -F '[-\t]' 'BEGIN{{OFS="\t"}} $2=="plus"{{print $1, $3, $4, "up_"NR, $5, "+"}} $2=="minus"{{print $1, $3, $4, "up_"NR, $5, "-"}}' | LC_COLLATE=C sort -k1,1 -k2,2n > {output.up}) &> {log}
        (awk 'BEGIN{{FS=OFS="\t"}}{{print $1, $3":"(-log($7)/log(10))}}' {input.down}| awk -F '[-\t]' 'BEGIN{{OFS="\t"}} $2=="plus"{{print $1, $3, $4, "down_"NR, $6, "+"}} $2=="minus"{{print $1, $3, $4, "down_"NR, $6, "-"}}' | LC_COLLATE=C sort -k1,1 -k2,2n > {output.down}) &>> {log}
        """
#COLUMN 6 FOR DOWN TABLES VS COLUMN 5 FOR UP TABLES IS DUE TO THE NEGATIVE SIGNS

rule get_putative_intragenic:
    input:
        peaks = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-{direction}.bed",
        orfs = config["genome"]["orf-annotation"],
        genic_anno = os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "genic-regions.bed"
    output:
        "diff_exp/{condition}-v-{control}/intragenic/{condition}-v-{control}-de-clusters-{norm}-{direction}-intragenic.tsv"
    log: "logs/get_putative_intragenic/get_putative_intragenic-{condition}-v-{control}-{norm}-{direction}.log"
    shell: """
        (bedtools intersect -a {input.peaks} -b {input.genic_anno} -v -s | bedtools intersect -a stdin -b {input.orfs} -wo -s | awk 'BEGIN{{FS="\t|:";OFS="\t"}} $7=="+"{{print $1, $7, $2, $3, $4, $9, $10, $11, $5, $6, ((($2+1)+$3)/2)-$9}} $7=="-"{{print $1, $7, $2, $3, $4, $9, $10, $11, $5, $6, $10-((($2+1)+$3)/2)}}' | sort -k10,10nr > {output}) &> {log}
        """

rule get_intragenic_frequency:
    input:
        orfs = config["genome"]["orf-annotation"],
        intrabed = "diff_exp/{condition}-v-{control}/intragenic/{condition}-v-{control}-de-clusters-{norm}-{direction}-intragenic.bed"
    output:
        "diff_exp/{condition}-v-{control}/intragenic/intrafreq/{condition}-v-{control}-de-clusters-{norm}-{direction}-intrafreq.tsv"
    shell: """
        bedtools intersect -a {input.orfs} -b {input.intrabed} -c -s > {output}
        """

rule plot_intragenic_frequency:
    input:
        "diff_exp/{condition}-v-{control}/intragenic/intrafreq/{condition}-v-{control}-de-clusters-{norm}-{direction}-intrafreq.tsv"
    output:
        "diff_exp/{condition}-v-{control}/intragenic/intrafreq/{condition}-v-{control}-intragenic-{norm}-{direction}-freqperORF.png"
    log: "logs/plot_intragenic_frequency/plot_intragenic_frequency-{condition}-v-{control}-{norm}-{direction}.log"
    script: "scripts/intrafreq.R"


#(echo -e "chrom\tpeak_strand\tpeak_start\tpeak_end\tpeak_name\torf_start\torf_end\torf_name\tpeak_lfc\tpeak_significance\tdist_peak_to_atg\n$
rule get_putative_antisense:
    input:
        peaks = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-{direction}.bed",
        transcripts = config["genome"]["transcripts"]
    output:
        "diff_exp/{condition}-v-{control}/antisense/{condition}-v-{control}-de-clusters-{norm}-{direction}-antisense.tsv"
    log : "logs/get_putative_antisense/get_putative_antisense-{condition}-v-{control}-{norm}-{direction}.log"
    shell: """
        (bedtools intersect -a {input.peaks} -b {input.transcripts} -wo -S | awk 'BEGIN{{FS="\t|:";OFS="\t"}} $7=="+"{{print $1, $7, $2, $3, $4, $9, $10, $11, $5, $6, $10-((($2+1)+$3)/2)}} $7=="-"{{print $1, $7, $2, $3, $4, $9, $10, $11, $5, $6, ((($2+1)+$3)/2)-$9}}' | sort -k10,10nr > {output}) &> {log}
        """
#(echo -e "chrom\tpeak_strand\tpeak_start\tpeak_end\tpeak_name\ttranscript_start\ttranscript_end\ttranscript_name\tpeak_lfc\tpeak_significance\tdist_peak_to_senseTSS\n$

rule build_genic_annotation:
    input:
        transcripts = config["genome"]["transcripts"],
        orfs = config["genome"]["orf-annotation"],
        chrsizes = config["genome"]["chrsizes"]
    output:
        os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "genic-regions.bed"
    params:
        windowsize = config["genic-windowsize"]
    log : "logs/build_genic_annotation.log"
    shell: """
        (python scripts/make_genic_annotation.py -t {input.transcripts} -o {input.orfs} -d {params.windowsize} -g {input.chrsizes} -p {output}) &> {log}
        """

rule get_putative_genic:
    input:
        peaks = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-{direction}.bed",
        annotation = os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "genic-regions.bed"
    output:
        "diff_exp/{condition}-v-{control}/genic/{condition}-v-{control}-de-clusters-{norm}-{direction}-genic.tsv"
    log : "logs/get_putative_genic/get_putative_genic-{condition}-v-{control}-{norm}-{direction}.log"
    shell: """
        (bedtools intersect -a {input.peaks} -b {input.annotation} -wo -s | awk 'BEGIN{{FS="\t|:";OFS="\t"}} $7=="+"{{print $1, $7, $2, $3, $4, $9, $10, $11, $5, $6}} $7=="-"{{print $1, $7, $2, $3, $4, $9, $10, $11, $5, $6}}' | sort -k10,10nr > {output}) &> {log}
        """
#(echo -e "chrom\tpeak_strand\tpeak_start\tpeak_end\tpeak_name\ttranscript_start\ttranscript_end\ttranscript_name\tpeak_lfc\tpeak_significance\n$

rule build_intergenic_annotation:
    input:
        transcripts = config["genome"]["transcripts"],
        chrsizes = config["genome"]["chrsizes"]
    output:
        os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "intergenic-regions.bed"
    params:
        genic_up = config["genic-windowsize"]
    log: "logs/build_intergenic_annotation.log"
    shell: """
        (sort -k1,1 {input.chrsizes} > .chrsizes.temp) &> {log}
        (bedtools slop -s -l {params.genic_up} -r 0 -i {input.transcripts} -g {input.chrsizes} | sort -k1,1 -k2,2n | bedtools complement -i stdin -g .chrsizes.temp > {output}) &>> {log}
        (rm .chrsizes.temp) &>> {log}
        """

rule get_putative_intergenic:
    input:
        peaks = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-{direction}.bed",
        annotation = os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "intergenic-regions.bed"
    output:
        "diff_exp/{condition}-v-{control}/intergenic/{condition}-v-{control}-de-clusters-{norm}-{direction}-intergenic.tsv"
    log : "logs/get_putative_intergenic/get_putative_intergenic-{condition}-v-{control}-{norm}-{direction}.log"
    shell: """
        (bedtools intersect -a {input.peaks} -b {input.annotation} -wo | awk 'BEGIN{{FS="\t|:";OFS="\t"}}{{print $1, $7, $2, $3, $4, $9, $10, ".", $5, $6}}'| sort -k10,10nr > {output}) &> {log}
        """
#(echo -e "chrom\tpeak_strand\tpeak_start\tpeak_end\tpeak_name\tregion_start\tregion_end\tregion_name\tpeak_lfc\tpeak_significance\n

rule get_intra_orfs:
    input:
        peaks = "diff_exp/{condition}-v-{control}/intragenic/{condition}-v-{control}-de-clusters-{norm}-{direction}-intragenic.tsv",
        fasta = config["genome"]["fasta"]
    output:
        "diff_exp/{condition}-v-{control}/intragenic/intragenic-orfs/{condition}-v-{control}-{norm}-{direction}-intragenic-orfs.tsv"
    params:
        max_upstr_atgs = config["max-upstr-atgs"],
        max_search_dist = 2000
    log: "logs/get_intra_orfs/get_intra_orfs-{condition}-v-{control}-{norm}-{direction}.log"
    shell: """
        (python scripts/find_intra_orfs.py -p {input.peaks} -f {input.fasta} -m {params.max_search_dist} -a {params.max_upstr_atgs} -o {output}) &> {log}
        """

rule build_convergent_annotation:
    input:
        transcripts = config["genome"]["transcripts"],
    output:
        os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "convergent-regions.bed"
    params:
        max_dist = config["max-convergent-dist"]
    log: "logs/build_convergent_annotation.log"
    shell: """
        (awk -v adist={params.max_dist} 'BEGIN{{FS=OFS="\t"}} $6=="+" {{ if(($3-$2)>adist) print $1, $2, $2+adist, $4, $5, "-" ; else print $0 }} $6=="-" {{if (($3-$2)>adist) print $1, $3-adist, $3, $4, $5, "+"; else print $0}}' {input.transcripts} > {output}) &> {log}
        """

rule get_putative_convergent:
    input:
        peaks = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-{direction}.bed",
        conv_anno = os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "convergent-regions.bed",
        genic_anno = os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "genic-regions.bed"
    output:
        "diff_exp/{condition}-v-{control}/convergent/{condition}-v-{control}-de-clusters-{norm}-{direction}-convergent.tsv"
    log : "logs/get_putative_convergent/get_putative_convergent-{condition}-v-{control}-{norm}-{direction}.log"
    shell: """
        (bedtools intersect -a {input.peaks} -b {input.genic_anno} -v -s | bedtools intersect -a stdin -b {input.conv_anno} -wo -s | awk 'BEGIN{{FS="\t|:";OFS="\t"}} $7=="+"{{print $1, $7, $2, $3, $4, $9, $10, $11, $5, $6, $10-((($2+1)+$3)/2)}} $7=="-"{{print $1, $7, $2, $3, $4, $9, $10, $11, $5, $6, ((($2+1)+$3)/2)-$9}}' | sort -k10,10nr > {output}) &> {log}
        """
#(echo -e "chrom\tpeak_strand\tpeak_start\tpeak_end\tpeak_name\ttranscript_start\ttranscript_end\ttranscript_name\tpeak_lfc\tpeak_significance\tdist_peak_to_senseTSS\n$

rule build_divergent_annotation:
    input:
        transcripts = config["genome"]["transcripts"],
        chrsizes = config["genome"]["chrsizes"]
    output:
        os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "divergent-regions.bed"
    params:
        max_dist = config["max-divergent-dist"]
    log: "logs/build_divergent_annotation.log"
    shell: """
        (bedtools flank -l {params.max_dist} -r 0 -s -i {input.transcripts} -g {input.chrsizes} | awk 'BEGIN{{FS=OFS="\t"}} $6=="+"{{print $1, $2, $3, $4, $5, "-"}} $6=="-"{{print $1, $2, $3, $4, $5, "+"}}' > {output}) &> {log}
        """

rule get_putative_divergent:
    input:
        peaks = "diff_exp/{condition}-v-{control}/de_clusters/{condition}-v-{control}-de-clusters-{norm}-{direction}.bed",
        div_anno = os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "divergent-regions.bed",
        genic_anno = os.path.dirname(config["genome"]["transcripts"]) + "/" + config["combinedgenome"]["experimental_prefix"] + "genic-regions.bed"
    output:
        "diff_exp/{condition}-v-{control}/divergent/{condition}-v-{control}-de-clusters-{norm}-{direction}-divergent.tsv"
    log : "logs/get_putative_divergent/get_putative_divergent-{condition}-v-{control}-{norm}-{direction}.log"
    shell: """
        (bedtools intersect -a {input.peaks} -b {input.genic_anno} -v -s | bedtools intersect -a stdin -b {input.div_anno} -wo -s | awk 'BEGIN{{FS="\t|:";OFS="\t"}} $7=="+"{{print $1, $7, $2, $3, $4, $9, $10, $11, $5, $6, ((($2+1)+$3)/2)-$9}} $7=="-"{{print $1, $7, $2, $3, $4, $9, $10, $11, $5, $6, $10-((($2+1)+$3)/2)}}' | sort -k10,10nr > {output}) &> {log}
        """
#(echo -e "chrom\tpeak_strand\tpeak_start\tpeak_end\tpeak_name\ttranscript_start\ttranscript_end\ttranscript_name\tpeak_lfc\tpeak_significance\tdist_peak_to_senseTSS\n$

rule get_category_bed:
    input:
        "diff_exp/{condition}-v-{control}/{category}/{condition}-v-{control}-de-clusters-{norm}-{direction}-{category}.tsv"
    output:
        "diff_exp/{condition}-v-{control}/{category}/{condition}-v-{control}-de-clusters-{norm}-{direction}-{category}.bed"
    log: "logs/get_category_bed/get_category_bed-{condition}-v-{control}-{norm}-{direction}-{category}.log"
    shell: """
        (awk 'BEGIN{{FS=OFS="\t"}}{{print $1, $3, $4, $5, $10, $2}}' {input} | sort -k1,1 -k2,2n  > {output}) &> {log}
        """

rule get_peak_sequences:
    input:
        peaks = "diff_exp/{condition}-v-{control}/{category}/{condition}-v-{control}-de-clusters-{norm}-{direction}-{category}.bed",
        chrsizes = config["genome"]["chrsizes"],
        fasta = config["genome"]["fasta"]
    output:
        "diff_exp/{condition}-v-{control}/{category}/{condition}-v-{control}-de-clusters-{norm}-{direction}-{category}.fa"
    params:
        upstr = config["meme-chip"]["upstream-dist"],
        dnstr = config["meme-chip"]["downstream-dist"]
    log: "logs/get_peak_sequences/get_peak_sequences-{condition}-v-{control}-{norm}-{direction}-{category}.log"
    shell: """
        (bedtools slop -l {params.upstr} -r {params.dnstr} -s -i {input.peaks} -g {input.chrsizes} | bedtools getfasta -name -s -fi {input.fasta} -bed stdin > {output}) &> {log}
        """

rule meme_chip:
    input:
        seq = "diff_exp/{condition}-v-{control}/{category}/{condition}-v-{control}-de-clusters-{norm}-{direction}-{category}.fa",
        db = config["meme-chip"]["motif-database"]
    output:
        "diff_exp/{condition}-v-{control}/{category}/{condition}-v-{control}-{norm}-{direction}-{category}-motifs/index.html"
    params:
        ccut = config["meme-chip"]["max-frag-size"],
        mode = config["meme-chip"]["meme-mode"],
        nmotifs = config["meme-chip"]["meme-nmotifs"],
    #threads: config["threads"]
    shell: """
        meme-chip {input.seq} -oc diff_exp/{wildcards.condition}-v-{wildcards.control}/{wildcards.category}/{wildcards.condition}-v-{wildcards.control}-{wildcards.norm}-{wildcards.direction}-{wildcards.category}-motifs -db {input.db} -ccut {params.ccut} -meme-mod {params.mode} -meme-nmotifs {params.nmotifs} -meme-p 2
        """
rule class_v_genic:
    input:
        pclass_up = "diff_exp/{condition}-v-{control}/{type}/{condition}-v-{control}-de-clusters-{norm}-up-{type}.tsv",
        pclass_dn = "diff_exp/{condition}-v-{control}/{type}/{condition}-v-{control}-de-clusters-{norm}-down-{type}.tsv",
        genic = "diff_exp/{condition}-v-{control}/all_genic/{condition}-v-{control}-genic-{norm}.tsv",
    output:
        scatter_text = "diff_exp/{condition}-v-{control}/{type}/{type}-v-genic/{condition}-v-{control}-{type}-v-genic-{norm}-scattertext.png" ,
        scatter_nolabel = "diff_exp/{condition}-v-{control}/{type}/{type}-v-genic/{condition}-v-{control}-{type}-v-genic-{norm}-scatternotext.png",
        table = "diff_exp/{condition}-v-{control}/{type}/{type}-v-genic/{condition}-v-{control}-{type}-v-genic-{norm}.tsv"
    script:
        "scripts/class_v_genic.R"
