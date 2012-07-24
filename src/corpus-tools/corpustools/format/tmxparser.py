#!/usr/bin/env python
# −*− coding: utf−8 −*−

# pylint: disable=C0301,C0103,C0111
# pylint: disable-msg=R0902
# pylint: disable-msg=W0201

import codecs
import os.path
import sys
from xml.parsers.expat import ParserCreate
from xml.parsers.expat import ExpatError

from corpustools.lib.langcode import LangCode


class TMXParser(object):
    def __init__(self):
        self.source_lang = None
        self.target_lang = None
        self.source = []
        self.target = []
        self.in_seg = False

        self.parser = ParserCreate()
        self.parser.buffer_text = True
        self.parser.buffer_size = 4096
        self.parser.returns_unicode = True

        self.parser.StartElementHandler = self.start_element_handler
        self.parser.EndElementHandler = self.end_element_handler
        self.parser.CharacterDataHandler = self.char_data_handler


    @property
    def output_dir(self):
        return self._output_dir


    @output_dir.setter
    def output_dir(self, path):
        if os.path.isdir(path):
            self._output_dir = path


    def parse_file(self, filename, source_lang, target_lang):
        try:
            fp = open(filename, 'r')
        except IOError as e:
            print e
            sys.exit(e.errno)

        if self.output_dir is None:
            self.output_dir = os.path.dirname(filename)
        stem = os.path.splitext(os.path.basename(filename))[0]

        self.source_lang = LangCode(source_lang).TMX_form()
        self.target_lang = LangCode(target_lang).TMX_form()
        source_filepath = os.path.join(self.output_dir, stem + '.' + LangCode(source_lang).xx())
        target_filepath = os.path.join(self.output_dir, stem + '.' + LangCode(target_lang).xx())
        try:
            self.source_fp = codecs.open(source_filepath, 'w', 'utf-8')
            self.target_fp = codecs.open(target_filepath, 'w', 'utf-8')
        except IOError as e:
            print e
            sys.exit(e.errno)

        # whether success or fail, close the files and quit.
        try:
            self.parser.ParseFile(fp)
        except ExpatError as e:
            print e

        fp.close()
        self.source_fp.close()
        self.target_fp.close()


    def start_element_handler(self, name, attributes):
        if (self.in_seg):
            attrlist = [ attrname + "=" + '"'+ attributes[attrname] +'"' for attrname in attributes.keys()]
            attrstr = " ".join(attrlist)
            tagheader = "<" + name + " " + attrstr + ">"
            self.seg += tagheader
        if (name == u"tu"):
            self.source = []
            self.target = []
        if (name == u"tuv"):
            self.tuv_lang = attributes["xml:lang"]
        if (name == u"seg"):
            self.seg = u""
            self.in_seg = True


    def end_element_handler(self, name):
        if (name == u"tu"):
            self.source_fp.write(u' '.join(self.source) + os.linesep)
            self.target_fp.write(u' '.join(self.target) + os.linesep)
        if (name == u"tuv"):
            self.tuv_lang = None
        if (name == u"seg"):
            self.in_seg = False
            if self.tuv_lang == self.source_lang:
                self.source.extend(self.seg.splitlines())
            if self.tuv_lang == self.target_lang:
                self.target.extend(self.seg.splitlines())
            self.seg = u""
        if (self.in_seg):
            tagtail = "</" + name + ">"
            self.seg += tagtail


    def char_data_handler(self, data):
        if self.in_seg:
            self.seg += data