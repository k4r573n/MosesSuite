# -*- coding: utf-8 -*-

# pylint: disable=I0011,C0301,W0621

"""Lowercase module for corpus clean tool."""

import shutil

from corpustools.case.lowercase import lowercase_file


def run(clean, tools, step):                                # pylint: disable=I0011,W0613
    """clean module interface function."""
    ext = step["ext"]
    lowercase_corpus(clean, clean.source_lang, ext)
    lowercase_corpus(clean, clean.target_lang, ext)


def lowercase_corpus(clean, lang, ext):
    """lowercase corpus files."""
    corpus = clean.corpus_w(lang)
    corpus_lc = clean.corpus_w(lang, ext)
    lowercase_file(corpus, corpus_lc)
    shutil.copy(corpus_lc, corpus)
