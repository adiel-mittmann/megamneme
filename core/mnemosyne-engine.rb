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

require 'queue-engine'

require 'time'

# A scheduler that aims to behave in exactly the same way as Mnemosyne's default
# scheduler. Based on Mnemosyne 1.2.2, the latest stable version available when
# this code was written.
class MnemosyneEngine < QueueEngine

  def initialize(deck)
    super(deck)

    @grades = {
      0 => {:text => '0'},
      1 => {:text => '1'},
      2 => {:text => '2'},
      3 => {:text => '3'},
      4 => {:text => '4'},
      5 => {:text => '5'},
    }

    @learning_attributes = [:gr, :e, :ac_rp, :rt_rp, :lps, :ac_rp_l, :rt_rp_l, :l_rp, :n_rp]
    @max_grade0 = 5

    @priority = []
  end

  def name
    'mnemosyne'
  end

  def decode_card_attributes(data)
    {
      :grade                => data['gr']       ? Integer(data['gr'])                     : 0,
      :easiness             => data['e']        ? Float(data['e'])                        : 2.5,
      :acq_reps             => data['ac_rp']    ? Integer(data['ac_rp'])                  : 0,
      :ret_reps             => data['rt_rp']    ? Integer(data['rt_rp'])                  : 0,
      :lapses               => data['lps']      ? Integer(data['lps'])                    : 0,
      :acq_reps_since_lapse => data['ac_rp_l']  ? Integer(data['ac_rp_l'])                : 0,
      :ret_reps_since_lapse => data['rt_rp_l']  ? Integer(data['rt_rp_l'])                : 0,
      :last_rep             => data['l_rp']     ? Time.strptime(data['l_rp'], '%Y-%m-%d') : @today,
#      :next_rep             => data['n_rp']     ? Time.strptime(data['n_rp'], '%Y-%m-%d') : @today,
    }
  rescue
    decode_card_attributes({})
  end

  def encode_card_attributes(data)
    {
      'gr'      => data[:grade].to_s,
      'e'       => '%.2f' % data[:easiness],
      'ac_rp'   => data[:acq_reps].to_s,
      'rt_rp'   => data[:ret_reps].to_s,
      'lps'     => data[:lapses].to_s,
      'ac_rp_l' => data[:acq_reps_since_lapse].to_s,
      'rt_rp_l' => data[:ret_reps_since_lapse].to_s,
      'l_rp'    => data[:last_rep].strftime('%Y-%m-%d'),
#      'n_rp'    => data[:next_rep].strftime('%Y-%m-%d'),
    }
  end

  def rebuild_revision_queue

    queue_clear()

    # 1. Review all cards in the review stack.

    # 1a. Review first cards that were scheduled to be repeated soon. Cards that
    # were scheduled to be repeated after big intervals will be reviewed last.
    review = @deck.review.current.sort{ |card| puts card; ((card.future ? card.future : @today) - card[:last_rep]) / one_day }
    queue_append(review, :review)

    # 1b. Cards from other stacks aren't allowed while there are cards left in
    # the review stack.
    return if queue_size > 0

    # 2. Find cards of grade 0 or 1 that once had a higher grade.

    grade0_count = 0

    grade0 = @deck.now.current.find_all{ |card| card[:lapses] > 0 && card[:grade] == 0 }
    grade1 = @deck.now.current.find_all{ |card| card[:lapses] > 0 && card[:grade] == 1 }

    # 2a. Cards that once had a high grade (2-5) but that during the review
    # process were assigned a low grade (0-1) have priority over other
    # cards. This priority, however, is only applied once, hence @priority is
    # cleared.
    @priority.each do |card|
      grade0.delete(card)
      grade0.unshift(card)
      grade1.delete(card)
      grade1.unshift(card)
    end
    @priority = []

    # 2b. Respect the limit for grade 0 cards.
    grade0 = grade0[0, @max_grade0]

    # 2c. A counter is needed for the following steps.
    grade0_count += grade0.size

    # 2d. Grade 0 cards are added twice to the queue. Since they are shuffled,
    # this effectively gives them a higher priority than grade 1 cards. If the
    # user assigns a high grade (2-5), then their duplicates will be removed.
    queue_append(grade0 * 2 + grade1, :now)
    queue_shuffle()

    # 2e. Regardless of the amount of grade 1 cards, if this limit was reached,
    # return now.
    return if grade0_count == @max_grade0

    # 3. Find cards of grade 0 or 1 that never had a higher grade. No
    # priorization is applied, since it is only relevant for cards that were
    # scheduled for today (and that therefore at some point in time had a grade
    # high grade (2-5)).

    grade0 = @deck.now.current.find_all{ |card| card[:lapses] == 0 && card[:grade] == 0 }[0, @max_grade0 - grade0_count]
    grade1 = @deck.now.current.find_all{ |card| card[:lapses] == 0 && card[:grade] == 1 }

    grade0_count += grade0.size
    
    queue_append(grade0 * 2 + grade1, :now)
    queue_shuffle()

    return if grade0_count == @max_grade0

    # 4. Since the amount of grade 0 cards is lower than the limit, complete the
    # queue with cards from the vocabulary.

    # 4b. The amount of grade 0 cards must be respected, and the quantity of new
    # cards cannot be greater than what is available in the vocabulary.
    new_count = [@max_grade0 - grade0_count, @deck.vocabulary.size].min

    # 4c. Cards are created by the deck, not here. This nil value will never be
    # accessed, but its presence ensures that new_count cards will be created.
    queue_append([nil] * new_count, :vocabulary)

  end

  def analyze_card(card)
    data = []
    destiny = []
    interval = []

    [0, 1, 2, 3, 4, 5].each do |grade|
      data[grade] = {}
      interval[grade] = nil
    end

    [0, 1].each do |grade|
      destiny[grade] = :now
    end
    [2, 3, 4, 5].each do |grade|
      destiny[grade] = :later
    end

    scheduled_interval = ((card.future ? card.future : @today) - card[:last_rep]) / one_day
    actual_interval = [(@today - card[:last_rep]) / one_day, 1].max

    puts 'data'
    puts scheduled_interval
    puts actual_interval
    puts card

    case

    # The card is being graded for the first time ever.
    when card[:acq_reps] == 0 && card[:ret_reps] == 0

      data[0..5].each do |data|
        data[:acq_reps] = 1
        data[:acq_reps_since_lapse] = 1
      end

      # Intervals for cards being graded for the first time are constant.
      [0, 0, 1, 3, 4, 5].each_with_index do |days, grade|
        interval[grade] = days
      end

    # The card had a grade of 0 or 1. It will be scheduled for either today (new
    # grade is low, 0-1) or tomorrow (new grade is high, 2-5)
    when [0, 1].include?(card[:grade])

      data[0..5].each do |data|
        data[:acq_reps] = card[:acq_reps] + 1
        data[:acq_reps_since_lapse] = card[:acq_reps_since_lapse] + 1
      end

      # The card will be shown today again.
      (0..1).each do |grade|
        interval[grade] = 0
      end

      # The card will be shown tomorrow.
      (2..5).each do |grade|
        interval[grade] = 1
      end

    # The card had a high grade. If its new grade is low (i.e., a lapse
    # occured), then the calculations are simple, otherwise not so much.
    when [2, 3, 4, 5].include?(card[:grade])

      # Update the easiness. Notice that, if the new grade is 0 or 1, the
      # easiness remains unchanged.
      if actual_interval >= scheduled_interval
        [0.0, 0.0, -0.16, -0.14, 0.0, 0.1].each_with_index do |delta, i|
          data[i][:easiness] = card[:easiness] + delta
        end
      end

      # New grade is low.
      data[0..1].each do |data|
        data[:ret_reps] = card[:ret_reps] + 1
        data[:lapses] = card[:lapses] + 1
        data[:acq_reps_since_lapse] = 0
        data[:ret_reps_since_lapse] = 0
      end
      (0..1).each do |grade|
        interval[grade] = 0
      end

      # New grade is high. First, update some fields.
      data[2..5].each do |data|
        data[:ret_reps] = card[:ret_reps] + 1
        data[:ret_reps_since_lapse] = card[:ret_reps_since_lapse] + 1
      end

      if card[:ret_reps_since_lapse] == 1

        # Really, I don't know what's this.
        (2..5).each do |grade|
          interval[grade] = 6
        end

      else

        # In all cases below, whenever the actual interval equals the scheduled
        # interval, the new interval is the product of the previous interval
        # with the easiness.

        (2..3).each do |grade|
          if actual_interval <= scheduled_interval
            interval[grade] = actual_interval * data[grade][:easiness]
          else
            interval[grade] = scheduled_interval
          end
        end

        (4..4).each do |grade|
          interval[grade] = actual_interval * data[grade][:easiness]
        end

        (5..5).each do |grade|
          if actual_interval < scheduled_interval
            interval[grade] = scheduled_interval
          else
            interval[grade] = actual_interval * data[grade][:easiness]
          end
        end

      end

    end

    (0..5).each do |grade|
      data[grade][:grade] = grade
      data[grade][:last_rep] = @today
      interval[grade] = (interval[grade] + calculate_interval_noise(interval[grade])) * one_day
    end

    analysis = {}
    (0..1).each do |grade|
      analysis[grade] = {:interval => interval[grade], :destiny => destiny[grade], :data => data[grade]}
    end
    (2..5).each do |grade|
      analysis[grade] = {:interval => interval[grade], :destiny => destiny[grade], :data => data[grade], :unit => :day}
    end

    return analysis

  end

  def grade_card(card, grade)

    # The basic actions are handled by a superclass.
    super(card, grade)

    # If the grade is high, then possible duplicates should be excluded from the
    # queue.
    if (2..5).include?(grade)
      queue_delete(card)
    end

    # If the grade is low and it was previously high, that means the user is
    # reviewing scheduled cards and there was a lapse. Give a high priority for
    # such a card.
    if (0..1).include?(grade) && (2..5).include?(card[:grade])
      @priority << card
    end

  end

  private

  # Calculates a noise value for an interval. Argument and return value are
  # whole days.
  def calculate_interval_noise(interval)
    case
    when interval == 0
      0
    when interval == 1
      (random * 2).to_i
    when interval <= 10
      -1 + (random * 3).to_i
    when interval <= 60
      -3 + (random * 7)
    else
      a = 0.05 * interval
      (-a + random * a * 2).round
    end
  end

end
