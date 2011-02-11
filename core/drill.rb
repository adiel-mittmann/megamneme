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

require 'project'
require 'undoable'

class Drill

  include Undoable

  attr_accessor :project, :deck, :engine

  def initialize(filename)
    @project = Project.new(filename)

    @engine = project.engine
    @deck = project.deck

    @new_cards = []
    @learned_cards = 0

    add_undo_dependencies([@deck, @engine])

    peek_next_card
  end

  def card
    @deck.current_card
  end

  def analysis
#    card.data = @engine.decode_card_attributes(card.data)
    result = @engine.analyze_card(card())
#    card.data = @engine.encode_card_attributes(card.data)
    return result
  end

  def grade(value)
    checkpoint()

    card = card()

    @deck.remove_card_todo

#    card.data = @engine.decode_card_attributes(card.data)
    analysis = @engine.analyze_card(card)

    if analysis[value][:destiny] == :later and @new_cards.include?(card)
      @new_cards.delete(card)
      @learned_cards += 1
    end

    @engine.grade_card(card, value)
#    card.data = @engine.encode_card_attributes(card.data)

    # if analysis[value][:interval] == 0
    #   card.future = nil
    # else
    #   card.future = Time.new + analysis[value][:interval]
    # end

    @deck.move_card(analysis[value][:destiny])

    peek_next_card
  end

  def flag
    checkpoint()
    card().flagged = card().flagged ? false : true
  end

  def ignore
    checkpoint()
    @deck.move_card(:ignored)
    peek_next_card
  end

  def delay
    checkpoint()
    @deck.move_card(:delayed)
    peek_next_card
  end

  def despair
    @engine.despair
  end

  def save(config_writer)
    @project.save(config_writer)
  end

  def learned_cards_count
    @learned_cards
  end

  protected

  def save_state
    log(:learned_cards, {:new_cards => @new_cards.clone, :learned_cards => @learned_cards});
  end

  def undo_learned_cards(action)
    @new_cards = action[:new_cards]
    @learned_cards = action[:learned_cards]
  end

  def peek_next_card

    card = nil

    origin = @engine.select_origin

    if origin != nil
      case
      when origin == :vocabulary
        card = @deck.peek_from_vocabulary
        card.data = @engine.initial_card_attributes
        @new_cards << card
      else
        card = @deck.peek_from_stack(origin, @engine.select_card(@deck.source_by_name(origin)))
      end
    end

    return card

  end

end
