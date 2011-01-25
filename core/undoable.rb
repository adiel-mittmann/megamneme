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

# A module to help objects undo actions applied to them.
#
# In order to use an undoable object, call #checkpoint whenever the object is in
# a state that you want to go back to, and then call #undo in order to return
# the object's state to its previous checkpoint. You can use #can_undo? to
# determine whether there are any actions to be undone.
#
# Classes that include Undoable should record every action that changes the
# object state by calling #log, and then undo all such actions by writing
# appropriate code in #undo_action.
#
# Alternatively, instead of recording incremental changes, classes may instead
# record the object's state immediately after every checkpoint. That can be
# accomplished by overriding #save_state.
#
# A hybrid approach (i.e., recording part of the state upon checkpoints and then
# recording incrementally changes to the other part of the state) is also
# possible.
module Undoable

  def checkpoint
    @undoable_log = [] if @undoable_log == nil
    @undoable_log << []
    if @undoable_deps != nil
      @undoable_deps.each do |dep|
        dep.checkpoint
      end
    end
    save_state
  end

  def undo
    @undoable_log = [] if @undoable_log == nil
    if @undoable_log.size == 0 then throw :nothing_to_undo end
    @undoable_log.pop.reverse_each do
      |action|
      begin
        method = self.method(('undo_' + action[:name].to_s).to_sym)
        method.call(action)
      rescue
        undo_action(action)
      end
    end
    if @undoable_deps != nil
      @undoable_deps.each do |dep|
        dep.undo
      end
    end
  end

  def can_undo?
    @undoable_log = [] if @undoable_log == nil
    @undoable_log.size > 0
  end

  def add_undo_dependencies(dep)
    @undoable_deps = [] if @undoable_deps == nil
    @undoable_deps += dep
  end

  protected

  def undo_action(action)
    throw :unknown_action_to_undo
  end

  def save_state
  end

  def log(name, desc = {})
    @undoable_log.last << {:name => name}.merge(desc)
  end

end
