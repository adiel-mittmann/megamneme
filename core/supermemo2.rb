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

class SuperMemo2


  attr_accessor :grades, :data

  def initialize
    @grades = {
      0 => {:text => '0'},
      1 => {:text => '1'},
      2 => {:text => '2'},
      3 => {:text => '3'},
      4 => {:text => '4'},
      5 => {:text => '5'},
    }
    @data = ['ef', 'rep', 'lint']
    @intervals = [0, 0, 1, 3, 7, 14, 21]
  end

  def calculateIntervals(card)
    day_secs = 24 * 60 * 60
    ef = card.data['ef'] != nil ? Float(card.data['ef']) : 2.5;
    rep = card.data['rep'] != nil ? Integer(card.data['rep']) : 0;
    lint = card.data['lint'] != nil ? Integer(card.data['lint']) : nil;
    int = {}
    int[0] = {:destiny => :later, :interval => day_secs, :repetition => 0}
    int[1] = {:destiny => :later, :interval => day_secs, :repetition => 0}
    int[2] = {:destiny => :later, :interval => day_secs, :repetition => 0}
    for i in 3..5
      if rep == 0
        int[i] = {:destiny => :later, :interval => day_secs, :repetition => 1}
      elsif rep == 1
        int[i] = {:destiny => :later, :interval => 6 * day_secs, :repetition => 2}
      else
        int[i] = {:destiny => :later, :interval => (lint * ef), :repetition => (rep + 1)}
      end
    end
    for i in 0..5
      new_ef = ef + (0.1 - (5 - i) * (0.08 + (5 - i) * 0.02));
      if new_ef < 1.3
        new_ef = 1.3
      end
      int[i][:easiness] = new_ef
    end
    return int
  end

  def updateCardData(card, grade)
    int = calculateIntervals(card)
    card.data['ef'] = sprintf("%.2f", int[grade][:easiness])
    card.data['rep'] = int[grade][:repetition].to_s
    card.data['lint'] = int[grade][:interval].to_s
  end

end
