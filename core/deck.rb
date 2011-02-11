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

require 'card'
require 'stack'
require 'vocabulary'
require 'engine'

require 'nokogiri'
require 'time'

class Deck

  include Undoable

  attr_accessor :now, :vocabulary, :review, :delayed, :later, :current_card

  def laterSize
    @later.fakeSize
  end

  def nowSize
    @now.fakeSize
  end

  def reviewSize
    @review.fakeSize
  end

  def delayedSize
    @delayed.size
  end

  def vocabularySize
    @vocabulary.size
  end

  def totalSize
    self.laterSize + self.nowSize + self.reviewSize + self.delayedSize + self.vocabularySize
  end

  def initialize(root, vocabulary)

    @later = Stack.new(:later)
    @now = Stack.new(:now)
    @review = Stack.new(:review)
    @delayed = Stack.new(:delayed)
    @ignored = Stack.new(:ignored)

    @vocabulary = nil
    @vocabulary_file = nil
    @current_card = nil

    @today = Time.new

#    @changes = []

    @max_new = 10
    @soon_minutes = 10

    @vocabulary = vocabulary

    add_undo_dependencies([@later, @now, @review, @ignored, @delayed, @vocabulary])

    def readStack(elem, stack)
      
      def readCard(elem)
        card = Card.new(elem['word'], elem['category'])
        if elem['future'] != nil
          card.future = Time.strptime(elem['future'], '%Y-%m-%d %H:%M:%S')
        end
        if elem['flagged'] == "yes"
          card.flagged = true
        end
        elem.attributes.each_pair{
          |key, value|
          if key != 'word' && key != 'category' && key != 'future' && key != 'flagged'
            card.data[key] = value.to_s;
          end
        }
        card
      end

      elem.element_children.each{
        |child|
        stack.add2(readCard(child))
      }
    end

    root.element_children.each{
      |child|
      case child.name
      when 'config'
        readConfig(child)
      when 'stack'
        case child['name']
        when 'later'
          readStack(child, @later)
        when 'now'
          readStack(child, @now)
        when 'review'
          readStack(child, @review)
        when 'ignored'
          readStack(child, @ignored)
        when 'delayed'
          readStack(child, @delayed)
        end
      end
    }

    @later.refresh(Time.new, false)
    @now.refresh(Time.new, false)

    scheduled = @later.pickAllCurrent
    for card in scheduled
      card.future = nil
    end
    @review.addManyCurrent(scheduled)

    discard = []
    for stack in [@later, @now, @review, @ignored, @delayed]
      for card in stack.getAllCards
        discard << {:word => card.word, :category => card.category}
      end
    end
    @vocabulary.discard_words(discard)

  end

  def save(doc, root)


    addStack = lambda do
      |doc, root, stack, name|
      stack_node = Nokogiri::XML::Node.new('stack', doc)
      root << stack_node
      stack_node['name'] = name
      cards = stack.getAllCards
      cards.each{
        |card|
        card_node = Nokogiri::XML::Node.new('card', doc)
        stack_node << card_node
        card_node['word'] = card.word
        if card.category != nil
          card_node['category'] = card.category
        end
        if card.future != nil
          card_node['future'] = card.future.strftime('%Y-%m-%d %H:%M:%S')
        end
        if card.flagged
          card_node['flagged'] = "yes"
        end
        card.data.each_pair{
          |key, value|
          card_node[key] = value;
        }
      }
    end

    addStack.call(doc, root, @later, 'later')
    addStack.call(doc, root, @now, 'now')
    addStack.call(doc, root, @review, 'review')
    addStack.call(doc, root, @delayed, 'delayed')
    addStack.call(doc, root, @ignored, 'ignored')

  end

  def decode_cards(engine)
    for stack in [@later, @now, @review, @ignored, @delayed]
      for card in stack.getAllCards
        card.data = engine.decode_card_attributes(card.data)
      end
    end
  end

  def encode_cards(engine)
    for stack in [@later, @now, @review, @ignored, @delayed]
      for card in stack.getAllCards
        card.data = engine.encode_card_attributes(card.data)
      end
    end
  end

  def peek_from_vocabulary
    word = @vocabulary.peek_next
    card = Card.new(word.word, word.category)
    @current_origin = @vocabulary
    @current_index = nil
    @current_card = card
    return card
  end

  def peek_from_stack(stack, index)
    stack = source_by_name(stack)
    card = stack.get(index)
    @current_origin = stack
    @current_card = card
    @current_index = index
    return card
  end

  def cancel
    if @current_card == nil
      throw :nothing_to_quit
    end
    logUndo
    @current_card = nil
    # change = @changes.last
    # if change.to == nil
    #   @changes.pop
    #   self.instance_variable_set(change.from, change.from_copy)
    #   @current_card = nil
    # end
  end

  def gradeCurrentCard(grade, algo)
    if @current_index == nil
      @vocabulary.remove_next
    else
      @current_origin.pickByIndex(@current_index);
    end
    int = algo.analyze_card(@current_card)
    algo.grade_card(@current_card, grade)
#    if int[grade][:interval] == 0
#      @current_card.future = nil
#    else
#      @current_card.future = Time.new + int[grade][:interval]
#    end
    puts @current_card.future
    moveCurrentCard(int[grade][:destiny])
  end

  def remove_card_todo
    if @current_index == nil
      @vocabulary.remove_next
    else
      @current_origin.pickByIndex(@current_index);
    end
  end

  def move_card(destiny)
    moveCurrentCard(destiny)
  end

  def source_by_name(name)
    case name
    when :review
      return @review
    when :now
      return @now
    when :vocabulary
      return @vocabulary
    end
  end

  def delayCurrentCard
    if @current_card == nil
      throw :no_current_card
    end
    moveCurrentCard(:@delayed)
  end

  def ignoreCurrentCard
    if @current_card == nil
      throw :no_current_card
    end
    moveCurrentCard(:@ignored)
  end

  def moveCurrentCard(destiny)
    if @current_card == nil
      throw :no_current_card
    end

    case destiny
    when :later
      destiny = :@later
    when :now
      destiny = :@now
    when :ignored
      destiny = :@ignored
    when :delayed
      destiny = :@delayed
    end

    # change = @changes.last
    # change.to = destiny
    # change.to_copy = self.instance_variable_get(destiny).copy

    destiny = self.instance_variable_get(destiny)

    puts (@current_card.flagged ? "FLAGGED" : "NOT FLAGGED")

    destiny.add(@current_card)

    @current_card = nil

  end

  protected

  def save_state
    log(:current_card, {:current_card => @current_card ? @current_card.copy : nil, :current_origin => @current_origin, :current_index => @current_index});
  end

  def undo_action(action)
    case
    when action[:name] == :current_card
      puts "NEW CURRENT CARD"
      puts action[:current_card]
      @current_card = action[:current_card]
      @current_origin = action[:current_origin]
      @current_index = action[:current_index]
    end
  end

end
