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

class Vocabulary

  include Undoable

  public

  def initialize(filename)

    # Keys are compound from the word plus its category; the values are Word
    # objects.
    @words = {}

    # Holds all categories that a given lemma possesses.
    @words_cats = {}

    # Used to sort words according to rank. This is needed because Words removed
    # from @words can't be placed back at their original location because @words
    # is a hash.
    @order = []

    if filename != nil

      text = IO.read(filename, nil, nil, {'encoding' => 'utf8'})

      if !read_xml(text)
        if !read_plain(text)
          throw :invalid_format
        end
      end

    end

  end

  def size
    @words.size
  end

  def peek_next
    if @words.size > 0
      @words[@order[0]]
    else
      nil
    end
  end

  def remove_next
    if @words.size > 0
      remove_word(0)
    else
      nil
    end
  end

  def discard_words(list)

    if can_undo?
      throw :cannot_log_this
    end

    list.each{
      |item|
      word = item[:word]
      category = item[:category]

      cats = @words_cats[word]

      if cats != nil
        if category != nil
          key = make_key(word, category)
          if @words.has_key?(key)
            @words.delete(key)
            cats.delete(category)
          end
        else
          for cat in cats
            key = make_key(word, cat)
            @words.delete(key)
          end
        end
        if cats.size == 0
          @words_cats.delete(word)
        end
      else
        key = make_key(word, nil)
        @words.delete(key)
      end
    }
    @order = @words.keys
    @order.sort{
      |a, b|
      @words[a].rank <=> @words[b].rank
    }
  end

  def to_s
    s = '== VOCABULARY =='"\n"
    s += 'words:'"\n"
    s += @words.to_s
    s += "\n"
    s += 'cats:'"\n"
    s += @words_cats.to_s
    s += "\n"
    s += 'order:'"\n"
    s += @order.to_s
    s += "\n"
    s += "end"
    s
  end

  protected

  class Word
    attr_accessor :word, :category, :rank

    def initialize(word, category, rank)
      @word = word
      @category = category
      @rank = rank
    end

    def to_s
      @word + ' (' + @category.to_s + ') (' + @rank.to_s + ')'
    end
  end


  def undo_action(action)
      case action[:name]
      when :remove
        if (action[:cats] != nil)
          @words_cats[action[:word].word] = action[:cats]
        end
        @words[action[:key]] = action[:word]
        @order.insert(action[:index], action[:key])
      end
  end

  def read_xml(xml)

    doc = Nokogiri::XML(xml, nil, 'utf-8')

    if doc.root == nil
      return false
    end

    def readVocabulary(elem)

      def readList(elem)
        rank = 1
        elem.element_children.each{
          |child|
          key = make_key(child.content, child['category'])
          if @words.has_key?(key)
            throw :duplicate_word
          end
          @words[key] = Word.new(child.content, child['category'], rank)
          @order << key
          cats = @words_cats[child.content]
          if cats == nil
            cats = (@words_cats[child.content] = [])
          end
          cats << child['category']
          rank += 1
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

    readVocabulary(doc.root)

    return true

  end

  def read_plain(text)
    rank = 1
    text.each_line{
      |line|
      line.strip!
      key = make_key(line, nil)
      if @words.has_key?(key)
        throw :duplicate_word
      end
      @words[key] = Word.new(line, nil, rank)
      @order << key
      rank += 1
    }
    true
  end

  def make_key(name, category)
    if category == nil
      name
    else
      name + '-' + category
    end
  end

  def remove_word(index)

    key = @order[index]
    word = @words.delete(key)
    cats = @words_cats[word.word]
    @order.slice!(index)

    log(:remove, {:index => index,
                  :key => key,
                  :word => word != nil ? word.clone : nil,
                  :cats => cats != nil ? cats.clone : nil});

    if cats != nil
      cats.delete(word.category)
      if cats.size == 0
        @words_cats.delete(word.word)
      end
    end

    return word

  end

end
