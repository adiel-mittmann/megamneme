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

class Card

  attr_reader :word, :category
  attr_accessor :future, :data, :flagged

  def initialize(word, category)
    @word = word
    @category = category
    @future = nil
    @data = {}
    @flagged = false
  end

  def copy
    card = Card.new(@word == nil ? nil : @word.clone, @category == nil ? nil : @category.clone)
    card.future = @future.clone if @future != nil
    card.data = @data.clone
    card.flagged = @flagged
    return card
  end

  def to_s
    return "word: %s, category: %s, data: %s" % [@word, @category, @data]
  end

  def [](name)
    @data[name]
  end

  def []=(name, value)
    @data[name] = value
  end

  def ==(other)
    if other == nil
      false
    else
      @word == other.word && @category == other.category
    end
  end

end
