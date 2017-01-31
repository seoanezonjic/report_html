require 'erb'
require 'fileutils'
require 'json'
require 'base64'

JS_FOLDER = File.expand_path(File.join(__FILE__, '..', '..', '..', 'js'))

class Report_html
	def initialize(hash_vars, title = "report", data_from_files = false)
		@all_report = ""
		@title = title
		@hash_vars = hash_vars
		@data_from_files = data_from_files
		@plots_data = []
		@count_objects = 0
	end

	def build(template)
		renderered_template = ERB.new(template).result(binding)
		@all_report = "<HTML>\n"
		make_head
		build_body do 
			renderered_template
		end
		@all_report << "\n</HTML>"
	end

	def build_body
		@all_report << "<body onload=\"initPage();\">\n#{yield}\n</body>\n"
	end

	def make_head
		@all_report << "\t<title>#{@title}</title>
			<head>
			    <meta http-equiv=\"CACHE-CONTROL\" CONTENT=\"NO-CACHE\">
    			<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />
    			<meta http-equiv=\"Content-Language\" content=\"en-us\" />

    			<link rel=\"stylesheet\" href=\"js/canvasXpress.css\" type=\"text/css\"/>
    			<script type=\"text/javascript\" src=\"js/canvasXpress.min.js\"></script>
    			<script>
					var initPage = function () {        
						<% @plots_data.each do |plot_data| %>
							<%= plot_data %>
						<% end %>
					}
				</script>
			</head>\n"
	end

	def get_report #return all html string
		renderer = ERB.new(@all_report)
		return renderer.result(binding) #binding does accesible all the current ruby enviroment to erb
	end

	def write(file)
		dir = File.dirname(file)
		string_report = get_report
		FileUtils.cp_r(JS_FOLDER, dir) 
		File.open(file, 'w'){|f| f.puts string_report}
	end

	# REPORT SYNTAX METHODS
	###################################################################################

	# DATA MANIPULATION METHODS
	#-------------------------------------------------------------------------------------	
	def get_data(options)
		data = []
		data = extract_data(options)
		if @data_from_files # If data on container is loaded using html_report as lib, we don't care about data format
							# if data comes from files and is loaded as strings. We need to format correctly the data.
			rows = data.length
			cols = data.first.length
			if !options[:text]
				rows.times do |r|
					cols.times do |c|
						next if r == 0 && options[:header]
						next if c == 0 && options[:row_names]
						data[r][c] = data[r][c].to_f
					end
				end
			end
		end
		add_header_row_names(data, options)
		data = data.transpose if options[:transpose]
		return data
	end

	def add_header_row_names(data, options)
		if options[:add_header_row_names] # This check if html object needs a default header/row_names or not
			if !options[:header]
				range = 0..(data.first.length - 1)
				data.unshift(range.to_a)
			end
			if !options[:row_names]
				data.each_with_index do |row, i|
					row.unshift(i) 
				end
			end
		end
	end

	def extract_data(options)
		data = []
		ids = options[:id]
		fields = options[:fields]
		ids = ids.split(',') if ids.class == String && ids.include?(',') # String syntax
		if ids.class == Array
			fields = fields.split(';').map{|data_fields| data_fields.split(',').map{|fields| fields.to_i} } if fields.class == String # String syntax
			ids.each_with_index do |id, n|
				data_file = extract_fields(id, fields[n])
				if data.empty?
					data.concat(data_file)
				else
					data.each_with_index do |row, n|
						data[n] = row + data_file[n]
					end
				end
			end
		else
			fields = fields.first if fields.class == Array
			data = extract_fields(ids, options[:fields])
		end
		return data
	end

	def extract_fields(id, fields)
		data = []
		@hash_vars[id].each do |row|
			if fields.empty?
				data << row.dup # Dup generates a array copy that avoids to modify original objects on data manipulation creating graphs
			else
				data << fields.map{|field| row[field]} #Map without bang do the same than dup
			end
		end
		return data
	end

	# TABLE METHODS
	#-------------------------------------------------------------------------------------
	def table(user_options = {}, &block)
		options = {
			id: nil,
			header: false,
			row_names: false,
			add_header_row_names: false,
			transpose: false,
			fields: [],
			border: 1,
			cell_align: [],
			attrib: {}
		}
		options.merge!(user_options)
		table_attr = prepare_table_attribs(options[:attrib])
		array_data = get_data(options)
		block.call(array_data) if !block.nil?
		rowspan, colspan = get_col_n_row_span(array_data)
		html = "
		<table border=\"#{options[:border]}\" #{table_attr}>
			<% array_data.each_with_index do |row, i| %>
				<tr>
					<% row.each_with_index do |cell, j|
						if cell != 'colspan' && cell != 'rowspan' 
							if i == 0 && options[:header] %>
								<th <%= get_span(colspan, rowspan, i, j) %>><%= cell %></th>
							<% else %>
								<td <%= get_cell_align(options[:cell_align], j) %> <%= get_span(colspan, rowspan, i, j) %>><%= cell %></td>
							<% end 
						end %>
					<% end %>
				</tr>
			<% end %>
		</table>
		"
		return ERB.new(html).result(binding)
	end

	def get_span(colspan, rowspan, row, col)
		span = []
		colspan_value = colspan[row][col]
		rowspan_value = rowspan[row][col]
		if colspan_value > 1
			span << "colspan=\"#{colspan_value}\""
		end
		if rowspan_value > 1
			span << "rowspan=\"#{rowspan_value}\""
		end
		return span.join(' ')
	end

	def get_col_n_row_span(table)
		colspan = []
		rowspan = []
		last_row = 0
		table.each_with_index do |row, r|
			rowspan << Array.new(row.length, 1)
			colspan << Array.new(row.length, 1)
			last_col = 0
			row.each_with_index do |col, c|
				if col == 'colspan'
					colspan[r][last_col] += 1
				else
					last_col = c
				end
				if col == 'rowspan'
					rowspan[last_row][c] += 1
				else
					last_row = r
				end
			end
		end
		return rowspan, colspan
	end


	def get_cell_align(align_vector, position)
		cell_align = '' 
		if !align_vector.empty? 
			align = align_vector[position]
			cell_align = "align=\"#{align}\""
		end
		return cell_align
	end

	def prepare_table_attribs(attribs)
		attribs_string = ''
		if !attribs.empty?
			attribs.each do |attrib, value|
				attribs_string << "#{attrib}= \"#{value}\" "
			end
		end
		return attribs_string
	end


	# CANVASXPRESS METHODS
	#-------------------------------------------------------------------------------------
	def canvasXpress_main(user_options, block = nil)
		# Handle arguments
		#------------------------------------------
		options = {
			id: nil,
			fields: [],
			data_format: 'one_axis',
			responsive: true,
			height: '600px',
			width: '600px',
			header: false,
			row_names: false,
			add_header_row_names: true,
			transpose: true,
			x_label: 'x_axis',
			title: 'Title',
			config: {}
		}
		options.merge!(user_options)
		config = {
			'toolbarPermanent' => true,
			'xAxisTitle' => options[:x_label],
			'title' => options[:title]
		}
		config.merge!(options[:config])
		# Data manipulation
		#------------------------------------------
		data_array = get_data(options)
		block.call(data_array) if !block.nil?
		raise("ID #{options[:id]} has not data") if data_array.nil?
		
		samples = data_array.shift[1..data_array.first.length]
		vars = []
		data_array.each do |row|
			vars << row.shift
		end
		values = data_array

		yield(options, config, samples, vars, values)

		# Build JSON objects and Javascript code
		#-----------------------------------------------
		object_id = "obj_#{@count_objects}_#{config['graphType']}"
		@count_objects += 1
		data_structure = {
			'y' => {
				'vars' => vars,
				'smps' => samples,
				'data' => values
			}
		}
		events = false
		info = false
		afterRender = {}
		extracode = nil
		if options[:mod_data_structure] == 'boxplot'
			data_structure['y']['smps'] = nil
			data_structure.merge!({ 'x' => {'Factor' => samples}})
			extracode = "C#{object_id}.groupSamples([\"Factor\"]);"
		elsif options[:mod_data_structure] == 'circular'
			data_structure.merge!({ 'z' => {'Ring' => options[:ring_assignation]}})
			data_structure.merge!({ 'c' => options[:links]}) if !options[:links].nil?
		end
		plot_data = "
		var data = #{data_structure.to_json};
        var conf = #{config.to_json}; 
        var events = #{events.to_json};
        var info = #{info.to_json};
        var afterRender = #{afterRender.to_json};                
        var C#{object_id} = new CanvasXpress(\"#{object_id}\", data, conf, events, info, afterRender);\n#{extracode}\n"
        @plots_data << plot_data
        
        responsive = ''
        responsive = "responsive='true'" if options[:responsive]
		html = "<canvas  id=\"#{object_id}\" width=\"#{options[:width]}\" height=\"#{options[:height]}\" aspectRatio='1:1' #{responsive}></canvas>"
		return ERB.new(html).result(binding)
	end

	def line(user_options = {}, &block)
		default_options = {
			row_names: true			
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values|
			config['graphType'] = 'Line'	
		end
		return html_string
	end

	def stacked(user_options = {}, &block)
		default_options = {
			row_names: true,
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values|
			config['graphType'] = 'Stacked'	
		end
		return html_string
	end
	
	def barplot(user_options = {}, &block)
		default_options = {
			row_names: true
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values|
			config['graphType'] = 'Bar'	
		end
		return html_string
	end

	def heatmap(user_options = {}, &block)
		default_options = {
			row_names: true
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values|
			config['graphType'] = 'Heatmap'	
		end
		return html_string
	end

	def boxplot(user_options = {}, &block)
		default_options = {
			row_names: true,
			header: true
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values|
			config['graphType'] = 'Boxplot'
			options[:mod_data_structure] = 'boxplot'	
		end
		return html_string
	end

	def pie(user_options = {}, &block) 
		default_options = {
			transpose: false
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values|
			config['graphType'] = 'Pie'
			if samples.length > 1
				config['showPieGrid'] = true
				config['xAxis'] = samples 
				config['layout'] = "#{(samples.length.to_f/2).ceil}X2" if config['layout'].nil?
				config['showPieSampleLabel'] = true if config['showPieSampleLabel'].nil?
			end
		end
		return html_string
	end

	def sccater2D(user_options = {}, &block)
		default_options = {
			row_names: false,
			transpose: false
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values|
			config['graphType'] = 'Scatter2D'
			config['xAxis'] = [samples.first]	
			config['yAxis']	= samples[1..samples.length-1]
			if default_options[:y_label].nil?
				config['yAxisTitle'] = 'y_axis'
			else
				config['yAxisTitle'] = default_options[:y_label]
			end
		end
		return html_string
	end

	def circular(user_options = {}, &block)
		default_options = {
			ring_assignation: [],
			ringsType: [],
			ringsWeight: []
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values|
			options[:mod_data_structure] = 'circular'
			config['graphType'] = 'Circular'
			config['segregateVariablesBy'] = ['Ring']
			if default_options[:ringsType].empty?
				config['ringsType'] = Array.new(vars.length, 'heatmap')
			else
				config['ringsType'] = default_options[:ringsType]
			end
			if default_options[:ringsWeight].empty?
				size = 100/vars.length
				config['ringsWeight'] = Array.new(vars.length, size)
			else
				config['ringsWeight'] = default_options[:ringsWeight]
			end
			if default_options[:ring_assignation].empty?
				options[:ring_assignation] = Array.new(vars.length) {|index| (index + 1).to_s}
			else
				options[:ring_assignation] = default_options[:ring_assignation].map{|item| item.to_s}
			end
			if !default_options[:links].nil?
				link_data = get_data({id: default_options[:links], fields: [], add_header_row_names: false, text: true, transpose: false})
				options[:links] = assign_rgb(link_data)
			end
		end
		return html_string
	end

	def assign_rgb(link_data)
		colors = {
			'red' => [255, 0, 0],
			'green' => [0, 255, 0],
			'black'	=> [0, 0, 0],
			'yellow' => [255, 255, 0],
			'blue' => [0, 0, 255],
			'gray' => [128, 128, 128],
			'orange' => [255, 165, 0],
			'cyan' => [0, 255, 255],
			'magenta' => [255, 0, 255]
		}
		link_data.each do |link|
			code = colors[link[0]]
			if !code.nil?
				link[0] = "rgb(#{code.join(',')})"
			else
				raise "Color link #{link} is not allowed. The allowed color names are: #{colors.keys.join(' ')}"
			end
		end
	end

	# EMBED FILES
	###################################################################################

	def embed_img(img_file, img_attribs = nil)
		img_content = File.open(img_file).read
		img_base64 = Base64.encode64(img_content)
		format = File.basename(img_file).split('.').last
		img_string = "<img #{img_attribs} src=\"data:image/#{format};base64,#{img_base64}\">"
		return img_string
	end

end