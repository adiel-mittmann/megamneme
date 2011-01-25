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

require 'xml-dictionary'

class TeiDictionary < XmlDictionary

  public

  def find_definitions(lemma, category)
    defs = []
    entries = @xml.xpath('/TEI.2/text/body/div0/entry[@key=$key]', nil, {:key => lemma})
    if entries.size == 0
      entries = @xml.xpath('/TEI.2/text/body/div0/superEntry[entry[@key=$key]]', nil, {:key => lemma + '1'})
      puts entries
    end
  end

end

#dict = XmlDictionary.new('/home/adiel/.megamneme/dict/abbyy-fr-ru.xml')
dict = TeiDictionary.new('/home/adiel/tus/194/Classics/Lewis/opensource/lewis.xml')
#GC.start

puts dict.find_definitions("populus", nil)
