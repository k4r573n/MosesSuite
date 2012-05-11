#!/bin/bash

# Train a sample model with IRSTLM support for FR-EN. 
#
# Project:      Moses Suite
# URL:          http://github.com/leohacker/MosesSuite
# Author:       Leo Jiang <leo.jiang.dev@gmail.com>
# Copyright:    Leo Jiang, 2012
# License:      GPL

set -x

# source common functions.
source moses-suite.functions
if [ $? != 0 ]; then
    echo "Failed to source moses-suite.functions."
    exit 1
fi

# source the moses configuration.
source_moses_conf

SCRIPTS_ROOT=${MOSES_SUITE_ROOT}/moses/scripts
check_dir "${SCRIPTS_ROOT}" "Moses script root directory."

TM_ROOT=${MOSES_DATA_ROOT}/translation_models/test/training-irstlm
check_dir "${TM_ROOT}"  "root directory of translation model training-irstlm"
if [ ! -w "${TM_ROOT}" ]; then
    echo "No permission for writing the directory ${TM_ROOT}"
    exit $E_ACCES
fi  
IRSTLM=${MOSES_SUITE_ROOT}/irstlm
check_var IRSTLM

setup_tm_tree ${TM_ROOT}

# Check the location of scritps and executable program.
# =====================================================
tokenizer=${SCRIPTS_ROOT}/tokenizer/tokenizer.perl
lowercaser=${SCRIPTS_ROOT}/tokenizer/lowercase.perl
detokenizer=${SCRIPTS_ROOT}/tokenizer/detokenizer.perl
clean_corpus_n=${SCRIPTS_ROOT}/training/clean-corpus-n.perl
train_truecaser=${SCRIPTS_ROOT}/recaser/train-truecaser.perl
truecaser=${SCRIPTS_ROOT}/recaser/truecase.perl

check_file "$tokenizer"     "European language tokenizer"
check_file "$lowercaser"    "lowercaser"
check_file "$detokenizer"   "detokenizer"
check_file "$clean_corpus_n"    "script clean long sentence"
check_file "$train_truecaser"   "script train truecase"
check_file "$truecaser"     "truecaser"

ngram_count=${MOSES_SUITE_ROOT}/srilm/bin/i686/ngram-count
train_model=${SCRIPTS_ROOT}/training/train-model.perl
moses=${MOSES_SUITE_ROOT}/moses/bin/moses
mertdir=${MOSES_SUITE_ROOT}/moses/bin
mert_moses=${SCRIPTS_ROOT}/training/mert-moses.pl
reuse_weights=${SCRIPTS_ROOT}/ems/support/reuse-weights.perl

check_file  "$ngram_count"      "srilm script ngram-count"
check_file  "$train_model"      "script train-model "
check_file  "$moses"            "moses core executable"
check_dir   "$mertdir"          "mert directory"
check_file  "$mert_moses"       "script mert-moses"
check_file  "$reuse_weights"    "script reuse-weights"

filter_model_given_input=${SCRIPTS_ROOT}/training/filter-model-given-input.pl
check_file  "$filter_model_given_input" "script of filter model with given input"

train_recaser=${SCRIPTS_ROOT}/recaser/train-recaser.perl
recaser=${SCRIPTS_ROOT}/recaser/recase.perl

check_file  "$train_recaser"    "script train-recaser"
check_file  "$recaser"          "script recaser"

# Prepare IRSTLM Corpus
# ============================================
cd ${TM_ROOT}

# Extra step for test-irstlm.
# --------------------------
cp news-commentary-v7.fr-en.fr corpus/training/
cp news-commentary-v7.fr-en.en corpus/training/
#cp nc-dev2007.fr corpus/tuning/
#cp nc-dev2007.en corpus/tuning/
#cp nc-test2007.fr corpus/evaluation/
#cp nc-test2007-ref.en.sgm corpus/evaluation/
#cp nc-test2007-src.fr.sgm corpus/evaluation/

# prepare training corpus.
# ------------------------
cd ${TM_ROOT}/corpus/training/
# tokenize the training corpus.
$tokenizer  -l fr < news-commentary-v7.fr-en.fr > news-commentary.tok.fr
$tokenizer  -l en < news-commentary-v7.fr-en.en > news-commentary.tok.en

## lowercase the tokenized corpus.
#$lowercaser < news-commentary.tok.fr > news-commentary.lowercased.fr
#$lowercaser < news-commentary.tok.en > news-commentary.lowercased.en

# truecase the corpus.
$train_truecaser --model truecase-model.en --corpus news-commentary.tok.en
$train_truecaser --model truecase-model.fr --corpus news-commentary.tok.fr

$truecaser --model truecase-model.fr < news-commentary.tok.fr > news-commentary.true.fr
$truecaser --model truecase-model.en < news-commentary.tok.en > news-commentary.true.en

$clean_corpus_n news-commentary.true fr en news-commentary.clean 1 80

# prepare lm corpus, same as full length lowercased corpus.
# ---------------------------------------------------------
#cd ${TM_ROOT}/corpus/
#cp training/news-commentary.lowercased.fr lm/news-commentary.lowercased.fr
#cp training/news-commentary.lowercased.en lm/news-commentary.lowercased.en

## prepare tuning corpus.
## ----------------------
#cd ${TM_ROOT}/corpus/tuning
#$tokenizer -l fr < nc-dev2007.fr > nc-dev2007.tok.fr
#$tokenizer -l en < nc-dev2007.en > nc-dev2007.tok.en
#$lowercaser < nc-dev2007.tok.fr > nc-dev2007.lowercased.fr
#$lowercaser < nc-dev2007.tok.en > nc-dev2007.lowercased.en
#
## prepare evaluation corpus.
## --------------------------
#cd ${TM_ROOT}/corpus/evaluation
#$tokenizer -l fr < nc-test2007.fr > nc-test2007.tok.fr
#$lowercaser < nc-test2007.tok.fr > nc-test2007.lowercased.fr

# Build Language Model and Train Phrase Model
# ===========================================
cd ${TM_ROOT}
# use irstlm to build lm.
$IRSTLM/bin/add-start-end.sh < corpus/training/news-commentary.true.en > lm/news-commentary.sb.en
cd lm
$IRSTLM/bin/build-lm.sh -i news-commentary.sb.en -t /tmp -p -s improved-kneser-ney -o news-commentary.lm.en
$IRSTLM/bin/compile-lm --text yes news-commentary.lm.en.gz news-commentary.arpa.en

# binarise the output irstlm lm file using KenLM.
${MOSES_SUITE_ROOT}/moses/bin/build_binary news-commentary.arpa.en news-commentary.blm.en

echo "is this an English sentence ?" | ${MOSES_SUITE_ROOT}/moses/bin/query news-commentary.blm.en

# train phrase model
cd ${TM_ROOT}
${train_model} -scripts-root-dir ${SCRIPTS_ROOT} --root-dir ${TM_ROOT} --corpus-dir ${TM_ROOT}/corpus/training/ --corpus ${TM_ROOT}/corpus/training/news-commentary.clean -f fr -e en -alignment grow-diag-final-and -reordering msd-bidirectional-fe -lm 0:3:${TM_ROOT}/lm/news-commentary.blm.en:8 >& ${TM_ROOT}/training.out

## Tuning 
## ===========================================
#${mert_moses} ${TM_ROOT}/corpus/tuning/nc-dev2007.lowercased.fr ${TM_ROOT}/corpus/tuning/nc-dev2007.lowercased.en $moses ${TM_ROOT}/model/moses.ini --working-dir ${TM_ROOT}/tuning/mert --mertdir $mertdir --rootdir ${SCRIPTS_ROOT} --decoder-flags "-v 0" >& ${TM_ROOT}/tuning/mert.out 
#${reuse_weights} ${TM_ROOT}/tuning/mert/moses.ini < ${TM_ROOT}/model/moses.ini > ${TM_ROOT}/tuning/moses-tuned.ini
#
## Filter Transaltion Model according to evaluation corpus
## =======================================================
#if [ -d ${TM_ROOT}/evaluation/filtered.nc-test2007 ]; then
#    rm -rf ${TM_ROOT}/evaluation/filtered.nc-test2007
#fi
#
#$filter_model_given_input ${TM_ROOT}/evaluation/filtered.nc-test2007 ${TM_ROOT}/tuning/moses-tuned.ini ${TM_ROOT}/corpus/evaluation/nc-test2007.lowercased.fr
#
## Decoding Test Corpus
## ========================================================
#$moses -f ${TM_ROOT}/evaluation/filtered.nc-test2007/moses.ini -input-file ${TM_ROOT}/corpus/evaluation/nc-test2007.lowercased.fr 1> ${TM_ROOT}/corpus/evaluation/nc-test2007.tuned-filtered.output 2> ${TM_ROOT}/evaluation/tuned-filtered.decode.out
#
## Evaluation: Recaser, detokenizer, wrapper and mteval.
## ========================================================
#${train_recaser} -train-script ${train_model} -ngram-count ${ngram_count} -corpus ${TM_ROOT}/corpus/training/news-commentary.tok.en -dir ${TM_ROOT}/recaser -scripts-root-dir ${SCRIPTS_ROOT}
#
#$recaser -model ${TM_ROOT}/recaser/moses.ini -in ${TM_ROOT}/corpus/evaluation/nc-test2007.tuned-filtered.output -moses $moses > ${TM_ROOT}/corpus/evaluation/nc-test2007.tuned-filtered.output.recased
#
#$detokenizer -l en < ${TM_ROOT}/corpus/evaluation/nc-test2007.tuned-filtered.output.recased > ${TM_ROOT}/corpus/evaluation/nc-test2007.tuned-filtered.output.detokenized
#
## TODO: replace the wrap-xml with python script.
#${SCRIPTS_ROOT}/ems/support/wrap-xml.perl en ${TM_ROOT}/corpus/evaluation/nc-test2007-ref.en.sgm MosesSuite < ${TM_ROOT}/corpus/evaluation/nc-test2007.tuned-filtered.output.detokenized > ${TM_ROOT}/corpus/evaluation/nc-test2007.tuned-filtered.output.sgm
#
#sed -i -e "s/refset/tstset/" ${TM_ROOT}/corpus/evaluation/nc-test2007.tuned-filtered.output.sgm
#
#${SCRIPTS_ROOT}/generic/mteval-v12.pl -s ${TM_ROOT}/corpus/evaluation/nc-test2007-src.fr.sgm -r ${TM_ROOT}/corpus/evaluation/nc-test2007-ref.en.sgm -t ${TM_ROOT}/corpus/evaluation/nc-test2007.tuned-filtered.output.sgm -c