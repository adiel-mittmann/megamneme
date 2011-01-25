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

def trimNulls(s)
  if s.index("\0") != nil
    s.slice(0, s.index("\0"))
  else
    s
  end
end

class PdbFile

  def initialize(file_name)
    file = File.new(file_name, 'rb')
    @file = file.read()
    @code_table = {}
    @headwords = []
  end

  def parse

    section_count = readUint16(0x004c)
    @sections = {}
    for i in 1..section_count
      pos = 0x004c + 2 + (i - 1) * 8
      address = readUint32(pos)
      index = readUint32(pos + 4)
      @sections[index] = {}
      @sections[index][:address] = address
    end

    readGeneralDescriptor

    i = 0x0100 + @style_sec_count * 0x0100

    readStyleSection(@sections[0x0100][:address])

#    puts @style

    items = []
    for j in 1..@hw_sec_count
      items += readHeadwordSection(@sections[i][:address], @sections[i + 0x0100][:address])
      i += 0x0200;
    end

    @headwords = items

    readDefinitionSection(@sections[i][:address], true)

    puts items

  end

  def search(text, previous = [])
    puts 'SEARCH: ' + text
    result = ''
    sup = []
    @headwords.each do
      |item|
      if not previous.include?(item.first)
        hw = item.first.gsub(/[ ,].*/, '')
        hw = hw.gsub(/\([0-9]\)/, '')
        found = false
        if hw.include?('(') and (hw.gsub(/\(.*\)/, '') == text or hw.gsub(/[\(\)]/, '') == text)
          found = true
        elsif hw == text
          found = true
        end
        if found
          puts 'FOUND: ' + item.first
          previous << item.first
          address = @sections[readUint16(item[1]) * 0x0100][:address] + readUint16(item[1] + 2)
          s = readTillNull(address)
          entry = formatEntry(decodeString2(s))
          prefix = entry.gsub(/(.*)<\/b>\|.*/, '\\1').gsub(/<div>/, '').gsub(/<b>/, '').gsub(/<\/b>/, '').gsub("\u0301", '')
          entry.gsub(/→ <b>([^<]*)<\/b>/) do
            match = $1
            if match =~ /^~/
              sup << match.gsub('~', prefix).gsub("\u0301", '').gsub(/ [0-9]*$/, '').gsub(/\(.*\)/, '')
            else
              sup << match.gsub('~', hw).gsub("\u0301", '').gsub(/ [0-9]*$/, '').gsub(/\(.*\)/, '')
            end
          end
#        t += '<div>' + prefix + '</div>'

          result += '<div>' + entry + '</div>'
        #+ (found ? 'found' : 'not found') + '<br/>' + sup.to_s
        end
      end
    end

    puts sup
    if sup != []
      sup.each do
        |text|
        puts 'DEEP DOWN: ' + text + ', ' + previous.to_s
        result += search(text, previous)
      end
    end

    return result
  end

  protected

  def readTillNull(pos)
    s = ''
    while @file[pos] != "\0"
      s += @file[pos]
      pos += 1
    end
    pos += 1
    s
  end

  def readStyleSection(offset)
    @style = {}
    i = offset + 0x31
    count = @file[i].ord
    i += 1
    for j in 1..count
      letter = @file[i + 1]
      desc = readTillNull(i + 2)
      @style[letter] = desc
      i += 0x56
    end
  end

  def readGeneralDescriptor
    pos = @sections[0x0000][:address]
    @style_sec_count = readUint16(pos)
    @hw_sec_count = readUint16(pos + 2)
    @basic_len = readUint8(pos + 6)
  end

  def niceString(s)
    for j in 0..(s.length - 1)
      if s[j].ord < 32 || s[j].ord > 127
        printf("\\x%02d", s[j].ord)
      else
        printf("%s", s[j])
      end
    end
    puts
  end

  def makeKey(s)
    if s != nil
      s[0].ord
    else
      nil
    end
  end

  def makeKey2(s, t)
    if s != nil && t != nil
      s[0].ord * 0x100 + t[0].ord
    else
      nil
    end
  end

  def decodeString2(s)
    pos = 0
#    puts "s: "
#    niceString(s)
    while pos < s.length
      key1 = makeKey2(s[pos    ], s[pos + 1])
      key2 = makeKey2(s[pos + 1], s[pos + 2])
      if @code_table.has_key?(key1)
        if @code_table.has_key?(makeKey(s[pos])) && @code_table.has_key?(key2) && @code_table[key2].last < @code_table[key1].last
          s = s.slice(0, pos) + @code_table[makeKey(s[pos])].first + s.slice(pos + 1..-1)
        else
          s = s.slice(0, pos) + @code_table[key1].first + s.slice(pos + 2..-1)
        end
      elsif @code_table.has_key?(makeKey(s[pos]))
        s = s.slice(0, pos) + @code_table[makeKey(s[pos])].first + s.slice(pos + 1..-1)
      else
        pos += 1
      end
#      puts "s: "
#      niceString(s)
    end
    s
  end

  def decodeString1(s)
    pos = 0
    while pos < s.length
      if @code_table.has_key?(s[pos].ord)
        s = s.slice(0, pos) + @code_table[s[pos].ord].first + s.slice(pos + 1..-1)
      else
        pos += 1
      end
    end
    s
  end

  def readDefinitionSection(offset, has_code_table)
    pos = offset
    readTillNull = lambda do
      s = ''
      while @file[pos] != "\0"
        s += @file[pos]
        pos += 1
      end
      pos += 1
      s
    end
    if has_code_table
      while (s = readTillNull.call).length > 0
        t = readTillNull.call
        if s.length == 1
          @code_table[makeKey(s)] = [t, pos]
        else
          @code_table[makeKey2(s[0], s[1])] = [t, pos]
        end
      end
      # @code_table.each_pair{
      #   |key, value|
      #   xey = '';
      #   for j in 0..(key.length - 1)
      #     xey += key[j].ord.to_s + ","
      #   end
      #   printf "%s = %s\n", xey, value
      # }
      @code_table.each_key{
        |key|
        @code_table[key][0] = decodeString1(@code_table[key].first)
      }
      t = readTillNull.call
      
    end
#     for i in 1..10000
#       s = readTillNull.call
# #      t = s.clone
# #      t.force_encoding('iso-8859-5')
# #      t = t.encode('utf-8')
# #      niceString(t)
#       puts '<div>' + formatEntry(decodeString2(s)) + '</div>'
#     end
  end

  def formatEntry(s)

    s.force_encoding('iso-8859-5')
    s = s.encode('utf-8')

    close = ''
    i = 0
    t = ''

    formatStyleChar = lambda do

      noclose = false
      fclose = ''

      style = @style[s[i + 1]]
      i += 1

      case style
      when 'oxfmini-normal'
        f = ''
      when 'oxfmini-bold'
        f = '<b>'
        fclose = '</b>'
      when 'oxfmini-italics'
        f = '<i>'
        fclose = '</i>'
      when 'oxfmini-symbol'
        i += 1
        sym = s[i]
        noclose = true
        case sym
        when '4'
          f = "\u0301"
        else
          case sym
          when '1'
            f = '→'
          when '5'
            f = '~̈'
          else
            f = "SYM(" + sym + ")"
          end
        end
      when 'oxfmini-new-line'
        f = '<br/>'
      else
        f = ''
      end

      r = ''
      if close.length > 0 && !noclose && fclose != close
        r += close
        close = ''
      end

      r += f

      if !noclose
        close = fclose
      end

      return r 
    end

    while i < s.length
      if s[i] == '$'
        t += formatStyleChar.call
      else
        t += s[i]
      end
      i += 1
    end

    if close.length
      t += close
    end

    t.gsub!(/<\/b><b>/, '')

    t
  end

  def readHeadwordSection(offset, limit)
    pos = offset
    offset2 = limit
    items = []
    items2 = []
    while pos < limit
      s = @file.slice(pos, @basic_len).chomp("\0")
      s = trimNulls(s)
      s.force_encoding('iso-8859-5')
      s = s.encode('utf-8')
      if s[0].ord < @basic_len
        s = items.last[0].slice(0, s[0].ord) + s.slice(1, s.length - 1)
        items << [s, -1]
      elsif s[0].ord < 32
        items[items.length - 1][0] += s.slice(1, s.length - 1)
      elsif s[0].ord == 0xff
      else
        items << [s, -1]
      end
      items.last[1] = offset2 + (pos - offset) / @basic_len * 4
      pos += @basic_len
    end
    items
  end

  def readUint8(pos)
    s = @file.slice(pos, 1)
    s[0].ord
  end

  def readUint16(pos)
    s = @file.slice(pos, 2)
    s[0].ord * 0x0100 + s[1].ord
  end

  def readUint32(pos)
    s = @file.slice(pos, 4)
    s[0].ord * 0x01000000 + s[1].ord * 0x00010000 + s[2].ord * 0x00000100 + s[3].ord * 0x00000001
  end

end

class Msdict

  class Definition
    attr_accessor :lemma, :index, :category, :content
    def initialize(lemma, index, category, content)
      @lemma = lemma
      @index = index
      @category = category
      @content = content
    end
    def to_s
      @lemma.to_s + '(' + @index.to_s + '), ' + @category.to_s + ': ' + @content
    end
  end

  def initialize(file_name)
    @pdb = PdbFile.new('/home/adiel/big/megamneme/dict/OxfPocketRussEng_j_1_1.pdb')
    @pdb.parse
  end
  def findDefinitions(lemma, category)
    return [Definition.new(lemma, nil, nil, @pdb.search(lemma))]
  end
end
