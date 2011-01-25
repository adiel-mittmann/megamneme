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

# An engine that selects new cards based on a queue. When the queue is empty, it
# is reconstructed.
class QueueEngine < Engine

  def initialize(deck)
    super(deck)
    @revision_queue = []
  end

  def select_origin()

    if @revision_queue.empty?
      rebuild_revision_queue
    end

    return nil if @revision_queue.empty?

    card = @revision_queue.first
    if card[:origin] == :vocabulary
      @revision_queue.shift
    end
    return card[:origin]
  end

  def select_card(stack)
    card = @revision_queue.shift
    @deck.source_by_name(card[:origin]).current.index(card[:card])
  end

  protected

  def queue_rebuild
  end

  def queue_clear
    @revision_queue = []
  end

  def queue_append(cards, origin)
    @revision_queue += cards.map{ |card| {:card => card, :origin => origin} }
  end

  def queue_size
    @revision_queue.size
  end

  def queue_shuffle
    @revision_queue.size.downto(1) { |n| @revision_queue.push @revision_queue.delete_at(random() * n) }
  end

  def queue_delete(card)
    @revision_queue.delete_if{ |queue_card| queue_card[:card] == card }
  end

  def undo_queue(action)
    @revision_queue = action[:queue]
  end

  def save_state
    log(:queue, :queue => @revision_queue.clone)
  end

end
