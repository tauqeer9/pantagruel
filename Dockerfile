FROM ubuntu:bionic

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y git build-essential cmake gcc g++ \
        linuxbrew-wrapper lftp clustalo raxml libhmsbeagle1v5 mrbayes r-base-core \
        r-recommended r-cran-ape r-cran-ade4 r-cran-vegan r-cran-dbi r-cran-rsqlite \
        r-cran-igraph r-cran-getopt sqlite3 sqlite3-doc libmagick++-dev python \
        python-scipy python-numpy python-biopython python-biopython-sql python-igraph \
        cython mpi-default-bin mpi-default-dev mrbayes-mpi python-pip \
        openjdk-11-jdk openjdk-11-jre parallel libdw1 libdw-dev libgsl23 libgsl-dev \
        libxml2-dev libcurl4-openssl-dev locales linuxbrew-wrapper rsync \
        libboost-dev libboost-serialization-dev libboost-mpi-dev \
        libbpp-core-dev libbpp-phyl-dev libbpp-seq-dev libbpp-seq-omics-dev \
		libdatetime-perl libxml-simple-perl libdigest-md5-perl bioperl \
		flex bison libgmp3-dev

RUN echo 'source("https://bioconductor.org/biocLite.R") ; biocLite("topGO") ; install.packages(c("phytools","pvclust"), repos="https://pbil.univ-lyon1.fr/CRAN/")' | R --vanilla

# HOMEBREW
#RUN localedef -i en_US -f UTF-8 en_US.UTF-8 \
#   && useradd -m -s /bin/bash linuxbrew \
#   && echo 'linuxbrew ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers
#USER linuxbrew
#WORKDIR /home/linuxbrew
#ENV USER=linuxbrew \
#    PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH \
#    SHELL=/bin/bash
#RUN HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_AUTO_UPDATE=1 brew tap brewsci/bio
#RUN HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_AUTO_UPDATE=1 mkdir -p /home/linuxbrew/.linuxbrew/var/homebrew/linked && brew doctor
#USER root
#WORKDIR /

# PERL modules
RUN cpan -T Module::Build Bio::Perl

# PYTHON libs
RUN pip install bcbio-gff bioscripts.convert

# BLAST+ v2.8.1 ( >= 2.8 required by Prokka)
ARG BLAST_TAG=2.8.1
ARG BLAST_NAME=ncbi-blast-${BLAST_TAG}+
ARG BLAST_ARCHIVE=${BLAST_NAME}-x64-linux.tar.gz
ARG BLAST_URL=ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/${BLAST_TAG}/${BLAST_ARCHIVE}
RUN cd /opt \
    && wget ${BLAST_URL} --progress=dot:giga \
    && tar xzf ${BLAST_ARCHIVE} \
    && rm ${BLAST_ARCHIVE}

# tbl2asn (Prokka dependency)
RUN cd / && wget --progress=dot:giga ftp://ftp.ncbi.nih.gov/toolbox/ncbi_tools/converters/by_program/tbl2asn/linux64.tbl2asn.gz \
    && gzip -d linux64.tbl2asn.gz && chmod +x linux64.tbl2asn && mv -f linux64.tbl2asn /usr/bin/tbl2asn

# add relevant locations to the PATH
ENV PATH="/pantagruel:/pantagruel/scripts:/pantagruel/scripts/pipeline:/opt/${BLAST_NAME}/bin:/MMseqs2/build/bin:/prokka/bin:/ALE/build/bin:/pal2nal.v14:/mad:${PATH}"
ENV PYTHONPATH="/pantagruel/python_libs:${PYTHONPATH}"

# PROKKA v1.14.5
#RUN brew install brewsci/bio/prokka && prokka --setupdb
RUN cd / && git clone https://github.com/tseemann/prokka.git \
    && cd prokka && git checkout v1.14.5
# set up Prokka
RUN prokka --setupdb

# MMSEQS v10
#RUN brew install mmseqs2
RUN cd / && git clone https://github.com/soedinglab/MMseqs2.git \
    && cd MMseqs2/ && git checkout 10-6d92c && mkdir build && cd build \
    && cmake -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=. .. \
    && make && make install

#PAL2NAL
RUN cd / && wget --progress=dot:giga http://www.bork.embl.de/pal2nal/distribution/pal2nal.v14.tar.gz \
    && tar -xzf pal2nal.v14.tar.gz \
    && chmod +x /pal2nal.v14/pal2nal.pl

#MAD
RUN cd / && wget --progress=dot:giga https://www.mikrobio.uni-kiel.de/de/ag-dagan/ressourcen/mad2-2.zip \
    && unzip mad2-2.zip && chmod +x /mad/mad

#INTERPROSCAN
#RUN (cd /usr/local && wget -O interproscan-5.35-74.0-64-bit.tar.gz ftp://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/5.35-74.0/interproscan-5.35-74.0-64-bit.tar.gz)

# LSD
RUN cd / && wget --progress=dot:giga -O /usr/bin/lsd https://github.com/tothuhien/lsd-0.3beta/releases/download/v0.3.3/lsd_unix \
    && chmod +x /usr/bin/lsd

# GeneRax
RUN cd / && git clone --recursive https://github.com/BenoitMorel/GeneRax \
    && cd GeneRax/ && ./install.sh

# make pantagruel executable and scripts available
# last echo command is a dummy one that can be edited so that build is resumed at this stage
COPY . /pantagruel
RUN cd /pantagruel \
    && echo "included pantagruel version: $(git log | head -n 1 | awk '{ print $2 }')" \
	&& echo "Dockerfile last edited on 2020-03-20"