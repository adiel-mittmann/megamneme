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

class Stack

  include Undoable

  attr_accessor :future, :current, :name

  def to_s
    s = '== STACK ' + @name.to_s + '  =='"\n"
    s += 'current:'"\n"
    @current.each{
      | card |
      s += card.to_s + "\n"
    }
    s += 'future:'"\n"
    @future.each{
      | card |
      s += card.to_s + "\n"
    }
    s += 'next_rand:' + @next_rand.to_s + "\n"
    s += 'end'
    s
  end

  def initialize(name)
    @future = []
    @current = []
    @next_rand = rand()
    @name = name
  end

  def size
    @current.size
  end

  def fakeSize
    @current.size + @future.size
  end

  def add2(card)
    if card.future != nil
      @future << card
    else
      @current << card
    end
  end

  def add(card)
    if card.future != nil
      log(:add, {:card => card.copy, :to => :future})
      puts 'CARD ADDED TO THE FUTURE'
      @future << card
    else
      log(:add, {:card => card.copy, :to => :current})
      @current << card
    end
  end

  def addManyCurrent(cards)
    @current += cards
  end

  def pickByIndex(i)
    card = remove(i)
    log(:remove, {:card => card.copy, :index => i, :rand => @next_rand})
    @next_rand = rand
    card
  end

  def get(i)
    puts 'GET CARD FROM STACK ' + @name.to_s + ' AT INDEX ' + i.to_s
    puts @current[i]
    @current[i]
  end


  def pickAllCurrent
    result = @current
    @current = []
    result
  end

  def refresh(now, log_this = true)
    offset = 0
    @future.map!.with_index{
      |card, index|
      if card.future <= now
        puts 'REFRESHING CARD(' + card.future.to_s + ', ' + now.to_s + '): ' + card.to_s
        if log_this
          log(:refresh, {:card => card.copy, :index => index + offset})
        end
        offset -= 1
        @current.unshift card
        nil
      else
        card
      end
    }.compact!
  end

  def getAllCards
    @future + @current
  end

  def undo_action(action)
    puts 'STACK UNDO: ' + action.to_s
    case action[:name]
    when :add
      case action[:to]
      when :future
        @future.pop
      when :current
        @current.pop
      end
    when :remove
      puts 'UNDOING :remove'
      puts self.to_s
      puts 'index: ' + action[:index].to_s
      puts 'card: ' + action[:card].to_s
      @current.insert(action[:index], action[:card])
      @next_rand = action[:rand]
    when :refresh
      @future.insert(action[:index], action[:card])
      @current.slice!(0)
    else
      super(action)
    end
  end

  public

  def remove(index)
    card = @current[index]
    @current.slice!(index)
    card
  end

end
