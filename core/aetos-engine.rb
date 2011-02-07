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

require 'engine'

class AetosEngine < Engine

  attr_reader :grades, :learning_attributes

  def initialize(deck)
    super(deck)

    @grades = {
      0 => {:text => '0'},
      1 => {:text => '1'},
      2 => {:text => '2', :stretch => 0.8},
      3 => {:text => '3', :stretch => 0.9},
      4 => {:text => '4', :stretch => 1.0},
      5 => {:text => '5', :stretch => 1.1},
      6 => {:text => '6', :stretch => 1.2},
    }
    @learning_attributes = [:stretch]
    @basic_intervals = [0, 0, 1, 3, 7, 14, 21]
  end

  def name
    'aetos'
  end

  def decode_card_attributes(data)
    {
      :stretch => data['stretch'] ? Float(data['stretch']) : 1.0
    }
  rescue
    decode_card_attributes({})
  end

  def select_origin()
    odds = {
      :vocabulary => 0,
      :review => 0,
      :now   => 0,
    }

    doomed = true

    if !@desperate && @deck.vocabulary.size > 0
      odds[:vocabulary] = 1.0
      doomed = false
    end

    if @deck.review.size > 0
      odds[:review] = doomed ? 1.0 : 0.9;
      doomed = false
    end

    @deck.now.refresh(Time.new)
#    if @deck.now.size > 1 || (@deck.now.size == 1 && doomed)
    if @deck.now.size > 0
      odds[:now] = doomed ? 1.0 : logarithmic(0.10, 1.00, 10, @deck.now.size);
      doomed = false
    end

    r = random
    case
    when r <= odds[:now]
      origin = :now
    when r <= odds[:review]
      origin = :review
    when r <= odds[:vocabulary]
      origin = :vocabulary
    else
      origin = nil
    end

    return origin
  end

  def select_card(stack)
    stack.refresh(Time.new)
    if stack.name != :now
      (random * stack.size).to_i
    else
      puts 'FROM NOW'
      case
      when stack.size == 1
        puts 'ZERO'
        0
      when stack.size == 2
        puts 'ZERO'
        0
      else
        total = ((stack.size - 1) + 1) * (stack.size - 1) / 2
        sum = 0
        r = random
        (0..(stack.size - 2)).each do
          |i|
          sum += (stack.size - i - 1)
          if Float(sum) / Float(total) >= r
            puts i
            return i
          end
        end
        throw :internal_error
      end
    end
  end

  def analyze_card(card)
    analysis = {}
    analysis[0] = {:destiny => :now, :interval => 0}
    analysis[1] = {:destiny => :now, :interval => 15 * 60}
    for i in 2..6
      int = (@basic_intervals[i] * card[:stretch]).round * one_day
      if i == 2 && int < one_day
        int = one_day
      elsif int <= analysis[i - 1][:interval]
        int = analysis[i - 1][:interval] + 1 * one_day
      end
      analysis[i] = {:destiny => :later, :interval => int, :unit => :day}
    end
    (0..1).each do |grade|
      analysis[grade][:data] = {}
    end
    (2..6).each do |grade|
      analysis[grade][:data] = {:stretch => card[:stretch] * @grades[grade][:stretch]}
    end
    return analysis
  end

  private

  def logarithmic(from, to, max, value)
    return from + Math.log(value) / Math.log(max) * (to - from)
  end

end
