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

require 'undoable'

require 'date'

class Engine

  include Undoable

  attr_reader :desperate, :grades, :learning_attributes

  def initialize(deck)
    @deck = deck
    @desperate = false
    @random = Random.new
    @today = Time.new.to_date.to_time
    @grades = {
      0 => {:text => '0'},
      1 => {:text => '1'},
      2 => {:text => '2'},
      3 => {:text => '3'},
      4 => {:text => '4'},
    }
    @learning_attributes = []
  end

  def name
    'engine'
  end

  def decode_card_attributes(data)
    data
  end

  def encode_card_attributes(data)
    result = {}
    learning_attributes().each do
      |attr|
      result[attr.to_s] = data[attr].to_s
    end
    return result
  end

  def initial_card_attributes
    decode_card_attributes({})
  end

  def select_origin
    return :review     if @deck.review.size > 0
    return :now        if @deck.now.size >= 5
    return :vocabulary if @deck.vocabulary.size > 0
    return nil
  end

  def select_card(stack)
    stack.refresh(Time.new)
    return (random() * stack.size).to_i
  end

  # Analyze the card give and return a hash specifying, for each grade, when it
  # should appear again (:interval), where it will go (:destiny) and new values
  # (if any) for some card data (:data).
  def analyze_card(card)
    analysis = {}
    grades().each_pair do
      |grade, desc|
      analysis[grade] = {:interval => one_day, :destiny => :later, :data => {}}
    end
    return analysis
  end

  def grade_card(card, grade)
    analysis = analyze_card(card)
    if analysis[grade][:interval] == 0
      card.future = nil
    else
      puts 'ANALYSIS'
      puts analysis[grade]
      if analysis[grade][:unit] == nil
        card.future = Time.new + analysis[grade][:interval]
      else
        case analysis[grade][:unit]
        when :second
          card.future = Time.new + analysis[grade][:interval]
        when :day
          card.future = (Time.new + analysis[grade][:interval]).to_date.to_time + 5 * 60 * 60
        end
      end
    end
    puts card.future
    card.data.merge!(analysis[grade][:data])
  end

  def despair
    log(:despair)
    @desperate = true
    puts "need to undo the following"
    @deck.now.refresh(Time.utc(2100, 1, 1))
  end

  protected

  def random
    return @random.rand
  end

  def undo_action(action)
    case action[:name]
    when :rand
      @random.marshal_load(action[:dump])
    when :despair
      @desperate = false
    else
      super(action)
    end
  end

  def save_state
    log(:rand, {:dump => @random.marshal_dump})
  end

  def one_day
    24 * 60 * 60
  end

end
