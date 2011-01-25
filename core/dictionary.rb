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

require 'file-manager'

require 'nokogiri'

class Dictionary

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

  def findDefinitions(lemma, category)

    word = @words[lemma]

    if word == nil
      return nil
    end

    defs = []

    if category == nil
      for entry in word.entries
        for defn in entry.definitions
          for item in defn.last
            defs << item
          end
        end
      end
    else
      for entry in word.entries
        if entry.definitions[category] != nil
          for defn in entry.definitions[category]
            defs << defn
          end
        end
        if entry.definitions[nil] != nil
          for defn in entry.definitions[nil]
            defs << defn
          end
        end
      end
    end

    return defs

  end

  def initialize(file_name)

    @words = {}

    file = File.new(FileManager.dictionary(file_name), 'rb')
    text = file.read()

    if !readXml(text)
      if !readPlain(text)
        throw :invalid_format
      end
    end

#    puts @words

  end

  private

  class Word
    attr_accessor :lemma, :entries
    def initialize(lemma)
      @lemma = lemma
      @entries = []
    end
  end

  class Entry
    attr_accessor :lemma, :index, :definitions
    def initialize(lemma, index)
      @lemma = lemma
      @index = index
      @definitions = {}
    end
  end

  def readXml(xml)

    doc = Nokogiri::XML(xml, nil, 'utf-8')

    if doc.root == nil
      return false
    end

    def readDictionary(elem)

      def readList(elem)

        elem.element_children.each{
          |child|
          lemma = child['lemma']
          index = child['index']
          word = @words[lemma]
          if word == nil
            word = (@words[lemma] = Word.new(lemma))
          end
          entry = Entry.new(lemma, index)
          word.entries << entry
          child.element_children.each{
            |child|
            category = child['category']
            defs = entry.definitions[category]
            if defs == nil
              defs = (entry.definitions[category] = [])
            end
            defs << Definition.new(lemma, index, category, child.first_element_child)
          }
        }
      end

      elem.element_children.each{
        |child|
        case child.name
        when 'info'
        when 'list'
          readList(child)
        end
      }
    end

    readDictionary(doc.root)

    return true

  end

  def readPlain(text)
    text.force_encoding('utf-8')
    text.each_line{
      |line|
      if line =~ /(.*) *= *(.*)/
        lemma = $~[1].strip
        definition = $~[2]
        word = Word.new(lemma)
        entry = Entry.new(lemma, 1)
        definition = Definition.new(lemma, 1, nil, definition)
        word.entries = [entry]
        entry.definitions[nil] = [definition]
        @words[lemma] = word
      elsif line.strip.length > 0
        throw 8000;
      end
    }
  end

end
