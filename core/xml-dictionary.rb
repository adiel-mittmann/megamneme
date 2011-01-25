# -*- coding: utf-8 -*-
#
# Copyright (c) 2011 Adiel Mittmann <adiel@inf.ufsc.br>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

require 'nokogiri'

class XmlDictionary

  public

  class Definition
    attr_accessor :lemma, :index, :category, :content
    def initialize(lemma, index, category, content)
      @lemma = lemma
      @index = index
      @category = category
      @content = content
    end
    def to_s
      @lemma.to_s + '(' + @index.to_s + '), ' + @category.to_s + ': ' + @content
    end
  end

  def find_definitions(lemma, category)
    defs = []
    @xml.xpath("/dictionary/list/entry[@lemma=$lemma]", nil, {:lemma => lemma}).each do
      |entry|
      defs << Definition.new(entry['lemma'], entry['index'], nil, entry.at_xpath('definition/*').to_xml(:encoding => 'utf-8'))
    end
    return defs
  end

  def initialize(file_name)
    file = File.new(file_name, 'rb')
    text = file.read()
    @xml = Nokogiri::XML(text, nil, 'utf-8', Nokogiri::XML::ParseOptions::NONET)
  end

end

#dict = XmlDictionary.new('/home/adiel/.megamneme/dict/abbyy-fr-ru.xml')
#dict = XmlDictionary.new('/home/adiel/tus/194/Classics/Lewis/opensource/lewis.xml')
#GC.start

#puts dict.find_definitions("d'abord", nil)
