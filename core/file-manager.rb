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

class FileManager

  def self.project(name)
    File.join(home, 'proj', name)
  end

  def self.dictionary(name)
    File.join(home, 'dict', name)
  end

  def self.vocabulary(name)
    File.join(home, 'vocab', name)
  end

  def self.engine(name)
    File.join(base, name + '-engine.rb')
  end

  def self.projects
    files = Dir.new(File.join(home, 'proj')).entries.reject{ |name| name == '.' || name == '..' }
  end

  def self.dictionaries
    files = Dir.new(File.join(home, 'dict')).entries.reject{ |name| name == '.' || name == '..' || File.directory?(name) }
  end

  private

  def self.base
    File.dirname(__FILE__)
  end

  def self.home
    File.join(File.expand_path('~'), '.megamneme')
  end

end
