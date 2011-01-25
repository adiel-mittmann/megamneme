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

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "core"))

require 'drill'
require 'file-manager'
require 'project'

require 'erb'
require 'sinatra/base'

require 'thread'

class Web < Sinatra::Base

  @@drills = {}
  @@options = {}
  @@locks = {}
  @@locks_lock = Mutex.new
  @@configs = {}

  def project(id, &block)
    @lock = nil
    @@locks_lock.synchronize do
      @@locks[id] = Mutex.new if @@locks[id] == nil
      @lock = @@locks[id]
    end
    @lock.synchronize do
      yield
    end
  end

  def load_drill(id)
    if !@@drills[id]
      @@drills[id] = Drill.new(id)
      @@options[id] = {}
      @@configs[id] = {}
      ui_config = @@drills[id].project.ui_config('ajaxui')
      if ui_config != nil
        ui_config.xpath('./dict').each do
          |dict|
          @@configs[id][dict['name']] = {:visible => (dict['visible'] == 'yes' ? true : false),
            :top => Float(dict['top']),
            :left => Float(dict['left']),
            :width => Float(dict['width']),
            :height => Float(dict['height'])}
        end
      end
    end
    @drill = @@drills[id]
    @config = @@configs[id]
    puts @config
  end

  get '/jquery/*' do
    send_file(File.join(File.dirname(__FILE__), 'jquery', params[:splat].first));
  end

  get '/icons/*' do
    send_file(File.join(File.dirname(__FILE__), 'icons', params[:splat].first));
  end

  get '/global.css' do
    content_type 'text/css'
    erb :"global/css"
  end

  get '/projects/view/' do
    @projects = FileManager.projects
    erb :'projects-view/html'
  end

  get '/projects/:id/grade/' do
    load_drill(params[:id])
    @grades = @drill.project.engine.grades
    content_type 'application/xhtml+xml', :charset => 'utf-8'
    erb :'projects-grade/html'
  end

  get '/projects/:id/grade/grade.js' do
    load_drill(params[:id])
    content_type 'application/javascript'
    @grades = @drill.project.engine.grades
    @project_id = params[:id]
    erb :'projects-grade/js'
  end

  get '/projects/:id/grade/grade.css' do
    load_drill(params[:id])
    content_type 'text/css'
    @grades = @drill.project.engine.grades
    erb :'projects-grade/css'
  end

  get '/projects/:id/grade/question' do
    project(params[:id]) do
      puts 'question-begin'
      load_drill(params[:id])
      card = @drill.card
      grades = @drill.project.engine.grades
      analysis = @drill.analysis()
      puts analysis
      xml = '<question>' +
        '<text>' +
        "<div class='word'>#{card.word}</div>" +
        "<div class='category'>#{card.category}</div>" +
        '</text>' +
        '<intervals>'

      xml += (card.flagged ? "<flagged/>" : "")


      grades.each_key do |grade|
        xml += '<interval>'
        xml += "<grade>#{grade}</grade>"
        int = (analysis[grade][:interval] / 24.0 / 3600.0).round
        xml += "<value><span>#{int}</span></value>"
        xml += '</interval>'
      end
      
      puts 'question-end'
      xml += '</intervals>' +
        '</question>'
    end
  end

  post '/projects/:id/grade/' do
    project(params[:id]) do
      puts 'post-grade-begin'
      load_drill(params[:id])
      if @drill.card == nil
        halt
      end
      @drill.grade(Integer(params[:grade]))
      puts 'post-grade-end'
      ''
    end
  end

  post '/projects/:id/grade/ignore' do
    load_drill(params[:id])
    @drill.ignore
    ''
  end

  post '/projects/:id/grade/flag' do
    load_drill(params[:id])
    @drill.flag
    ''
  end

  post '/projects/:id/grade/delay' do
    load_drill(params[:id])
    @drill.delay
    ''
  end

  post '/projects/:id/grade/undo' do
    load_drill(params[:id])
    @drill.undo
    ''
  end

  post '/projects/:id/grade/despair' do
    card = nil
    @@drill.deck.cancel
    @@drill.deck.desperateMode
    redirect '/grade'
  end

  def save_project(id)
    load_drill(id)
    @drill.save(lambda{
                  |doc, config|
                  puts 'huhuhuhuhu'
                  node = Nokogiri::XML::Node.new('ui', doc)
                  config << node
                  node['name'] = 'ajaxui'
                  @config.each_pair do
                    |name, data|
                    dict_node = Nokogiri::XML::Node.new('dict', doc)
                    node << dict_node
                    dict_node['name'] = name
                    dict_node['visible'] = data[:visible] ? 'yes' : 'no'
                    dict_node['top'] = data[:top].to_s
                    dict_node['left'] = data[:left].to_s
                    dict_node['width'] = data[:width].to_s
                    dict_node['height'] = data[:height].to_s
                  end
                })
    puts @config

      # ui_config = @@drills[id].project.ui_config('ajaxui')
      # if ui_config != nil
      #   ui_config.xpath('./dict').each do
      #     |dict|
      #     @@configs[id][dict['name']] = {:visible => (dict['visible'] == 'yes' ? true : false),
      #       :top => Float(dict['top']) / 100,
      #       :left => Float(dict['left']) / 100,
      #       :width => Float(dict['width']) / 100,
      #       :height => Float(dict['height']) / 100}
      #   end
      # end
  end

  get '/saveall' do
    @@drills.each_pair do
      |a, b|
      save_project(a)
    end
    ''
  end

  post '/projects/:id/save' do
    save_project(params[:id])
    ''
  end

  post '/projects/:id/close' do
    @@drill.deck.cancel
    @@drill.deck.save
    @@drill = nil
    card = nil
    redirect '/'
  end

  get '/projects/:id/grade/definition/:name' do
    load_drill(params[:id])
    html = ''
    dictionary = @drill.project.dictionaries[params[:name]]
    name = params[:name]
    html += '<div id="haha-dialog-' + name.gsub(".", "-") + '" title="' + name + '">'
    defs = dictionary.findDefinitions(@drill.card.word, nil)
    if defs != nil
      defs.each do
        |item|
        begin
          html += item.content.to_xml
        rescue
          html += item.content
        end
      end
    else
      html += '<i>Definition not found.</i>'
    end
    html += '</div>'
    html
  end

  get '/projects/:id/grade/status' do
    project(params[:id]) do
      puts 'status-begin'
      load_drill(params[:id])

      xml = ''
      xml += '<status>'

      [
       ['total', @drill.deck.totalSize],
       ['unseen', @drill.deck.vocabularySize],
       ['delayed', @drill.deck.delayedSize],
       ['later', @drill.deck.laterSize],
       ['review', @drill.deck.reviewSize],
       ['now', @drill.deck.nowSize],
       ['new', @drill.learned_cards_count],
      ].each do |item|
        xml += "<#{item.first}>#{item.last.to_s}</#{item.first}>"
      end

      puts 'status-end'
      xml += '</status>'
    end
  end

  get '/projects/:id/grade/dictionaries' do
    xml = ''
    xml += '<list>'
    FileManager.dictionaries.each do
      |item|
      xml += '<item>'
      xml += '<id>' + item.gsub(/[\.-]/, '_') + '</id>'
      xml += '<name>' + item + '</name>'
      xml += '</item>'
    end
    xml += '</list>'
  end

  post '/projects/:id/grade/dictionary/:dict/savesettings/:width/:height/:left/:top' do
    load_drill(params[:id]);
#    @drill.project.ui_config('ajaxui')[params[:dict]] = [params[:width], params[:height], params[:left], params[:top], :visible]
    if @config[params[:dict]] == nil
      @config[params[:dict]] = {}
    end
    @config[params[:dict]][:visible] = true
    @config[params[:dict]][:width] = Float(params[:width])
    @config[params[:dict]][:height] = Float(params[:height])
    @config[params[:dict]][:top] = Float(params[:top])
    @config[params[:dict]][:left] = Float(params[:left])
    ''
  end

  post '/projects/:id/grade/dictionary/:dict/hide' do
    load_drill(params[:id]);
#    @drill.project.ui_config('ajaxui')[params[:dict]][params[:dict]][4] = :hidden
    if @config[params[:dict]] == nil
      @config[params[:dict]] = {}
    end
    @config[params[:dict]][:visible] = false
    ''
  end

  get '/projects/:id/grade/dictionary/:dict/getsettings' do
    load_drill(params[:id]);
    puts 'EDW'
    puts params[:dict]
    if @config[params[:dict]] != nil
      return '<settings>' +
        (@config[params[:dict]][:visible] ? '' : '<hidden></hidden>') +
        '<width>' + @config[params[:dict]][:width].to_s + '</width>' +
        '<height>' +@config[params[:dict]][:height].to_s + '</height>' +
        '<left>' + @config[params[:dict]][:left].to_s + '</left>' +
        '<top>' + @config[params[:dict]][:top].to_s + '</top>' +
        '</settings>'
    end
    return ''
  end

end

Web.run!
