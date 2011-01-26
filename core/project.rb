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

require 'deck'
require 'dictionary'
require 'xml-dictionary'
require 'msdic'
require 'file-manager'
require 'vocabulary'

require 'nokogiri'

class Project

  attr_reader :deck, :vocabularies, :dictionaries, :engine, :ui

  def initialize(filename)
    @deck = nil
    @vocabularies = {}
    @dictionaries = {}
    @engine = nil
    @ui = {}

    read_xml(FileManager.project(filename))

    @deck.decode_cards(@engine)
#    @deck.each_card do
#      |card|
#      card.data = @engine.decode_card_attributes(card.data)
#    end

    @filename = filename
  end

  def save(config_writer)
    @deck.encode_cards(@engine)
    write_xml(@filename, config_writer)
    @deck.decode_cards(@engine)
  end

  def ui_config(name)
    return @ui[name]
  end

  protected

  def read_xml(filename)

    file = File.new(filename, 'rb')
    doc = Nokogiri::XML(file.read)

    config = doc.xpath('//config').first

    config.xpath('./vocabulary').each do
      |vocabulary|
      filename = vocabulary['file']
      @vocabularies[filename] = Vocabulary.new(FileManager.vocabulary(filename))
    end

    config.xpath('./dictionary').each do
      |dictionary|
      filename = dictionary['file']
      if filename =~ /.*\.pdb$/
        puts 'DICTIONARY'
        puts filename
        @dictionaries[filename] = Msdict.new(filename)
      elsif filename =~ /.*\.xml/
        puts filename
        @dictionaries[filename] = XmlDictionary.new(FileManager.dictionary(filename))
      end
    end

    config.xpath('./ui').each do
      |ui|
      @ui[ui['name']] = ui
    end

    @deck = Deck.new(doc.xpath('//deck').first, @vocabularies.first.last)

    engine_name = config.xpath('./engine').first['name']

    require(FileManager.engine(engine_name))
    engine_class = eval(engine_name.capitalize + 'Engine')
    @engine = engine_class.new(@deck)

  end

  def write_xml(filename, config_writer)

    doc = Nokogiri::XML::Document.new
    doc.encoding= 'utf-8'

    root = Nokogiri::XML::Node.new('project', doc)
    doc.root=(root)

    config = Nokogiri::XML::Node.new('config', doc)
    root << config

    engine_node = Nokogiri::XML::Node.new('engine', doc)
    config << engine_node
    engine_node['name'] = @engine.name

    @vocabularies.each_key do |name|
      vocab_node = Nokogiri::XML::Node.new('vocabulary', doc)
      config << vocab_node
      vocab_node['file'] = name
    end

    @dictionaries.each_key do |name|
      dict_node = Nokogiri::XML::Node.new('dictionary', doc)
      config << dict_node
      dict_node['file'] = name
    end

    config_writer.call(doc, config)

    deck_node = Nokogiri::XML::Node.new('deck', doc)
    root << deck_node
    @deck.save(doc, deck_node)

    f = File.new(FileManager.project(filename), 'wb')
    f.print(doc.to_xml)
    f.close

  end

end
