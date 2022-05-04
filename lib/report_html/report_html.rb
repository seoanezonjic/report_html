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
		@dt_tables = [] #Tables to be styled with the DataTables js lib"
		@bs_tables = [] #Tables to be styled with the bootstrap js lib"
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
		if !@plots_data.empty?
			@all_report << "<body onload=\"initPage();\">\n#{yield}\n</body>\n"
		else
			@all_report << "<body>\n#{yield}\n</body>\n"
		end
	end

	def load_js_libraries(js_libraries)
		loaded_libraries = []
		js_libraries.each do |js_lib|
			js_file = File.open(File.join(JS_FOLDER, js_lib)).read
			loaded_libraries << Base64.encode64(js_file)
		end
		return loaded_libraries
	end

	def load_css(css_files)
		loaded_css = []
		css_files.each do |css_lib|
			loaded_css << File.open(File.join(JS_FOLDER, css_lib)).read
		end
		return loaded_css
	end

	def make_head
		@all_report << "\t<title>#{@title}</title>
			<head>
				<meta charset=\"utf-8\">
			    <meta http-equiv=\"CACHE-CONTROL\" CONTENT=\"NO-CACHE\">
    			<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />
    			<meta http-equiv=\"Content-Language\" content=\"en-us\" />
    			<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, shrink-to-fit=no\">\n"

    	# ADD JS LIBRARIES AND CSS
		js_libraries = []
		css_files = []
		if !@plots_data.empty?
			js_libraries << 'canvasXpress.min.js'
			css_files << 'canvasXpress.css'
		end

	 	if !@dt_tables.empty? || !@bs_tables.empty? #Bootstrap for datatables or only for static tables. Use bootstrap version needed by datatables to avoid incompatibility issues
		 	@all_report << '<link rel="stylesheet" type="text/css" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css"/>'+"\n"
		end

		if !@dt_tables.empty? # CDN load, this library is difficult to embed in html file
		 	@all_report << '<link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.10.21/css/dataTables.bootstrap.min.css"/>'+"\n"
			@all_report << '<script type="text/javascript" src="https://code.jquery.com/jquery-3.5.1.js"></script>' + "\n"
			@all_report << '<script type="text/javascript" src="https://cdn.datatables.net/1.10.21/js/jquery.dataTables.min.js"></script>' + "\n"
			@all_report << '<script type="text/javascript" src="https://cdn.datatables.net/1.10.21/js/dataTables.bootstrap.min.js"></script>' + "\n"
	 	end	 	

		loaded_js_libraries = load_js_libraries(js_libraries)
		loaded_css = load_css(css_files)
    	loaded_css.each do |css|
			@all_report << "<style type=\"text/css\"/>
					#{css}
				</style>\n"
		end
    	loaded_js_libraries.each do |lib|
			@all_report << "<script src=\"data:application/javascript;base64,#{lib}\" type=\"application/javascript\"></script>\n"
		end
    	
    	# ADD CUSTOM FUNCTIONS TO USE LOADED JS LIBRARIES
    	#canvasXpress objects
    	if !@plots_data.empty?
	    	@all_report << "<script>
						var initPage = function () {        
							<% @plots_data.each do |plot_data| %>
								<%= plot_data %>
							<% end %>
						}
					</script>"
		end

    	#DT tables
    	if !@dt_tables.empty?
	    	@all_report << "<script>
							<% @dt_tables.each do |dt_table| %>
								$(document).ready(function () {
									$('#<%= dt_table %>').DataTable();
								});
								
							<% end %>
						</script>\n"
		end


		@all_report <<	"</head>\n"
	end

	def get_report #return all html string
		renderer = ERB.new(@all_report)
		return renderer.result(binding) #binding does accesible all the current ruby enviroment to erb
	end

	def write(file)
		#dir = File.dirname(file)
		string_report = get_report
		#FileUtils.cp_r(JS_FOLDER, dir) 
		File.open(file, 'w'){|f| f.puts string_report}
	end

	# REPORT SYNTAX METHODS
	###################################################################################

	# DATA MANIPULATION METHODS
	#-------------------------------------------------------------------------------------	
	def get_data(options)
		data, smp_attr, var_attr = extract_data(options)
		if !data.empty?
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
			if options[:transpose]
				data = data.transpose
				smp_attr_bkp = smp_attr
				smp_attr = var_attr
				var_attr = smp_attr_bkp
			end
		end
		return data, smp_attr, var_attr
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
		smp_attr = nil
		var_attr = nil
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
			smp_attr = process_attributes(extract_fields(ids, options[:smp_attr]), options[:var_attr], aggregated = true) if !options[:smp_attr].nil? && !options[:smp_attr].empty?
			var_attr = process_attributes(extract_rows(ids, options[:var_attr]), options[:smp_attr], aggregated = false) if !options[:var_attr].nil? && !options[:var_attr].empty?
			data = extract_fields(ids, options[:fields], del_fields = options[:smp_attr], del_rows = options[:var_attr])
		end
		return data, smp_attr, var_attr
	end

	def extract_fields(id, fields, del_fields = [], del_rows = [])
		data = []
		@hash_vars[id].each_with_index do |row, i|
			next if !del_rows.nil? && del_rows.include?(i)
			if fields.empty?
				row = row.dup # Dup generates a array copy that avoids to modify original objects on data manipulation creating graphs
				if !del_fields.nil? 
					del_fields.sort.reverse_each do |j|
						row.delete_at(j)
					end
				end
				data << row
			else
				data << fields.map{|field| row[field]} #Map without bang do the same than dup
			end
		end
		return data
	end

	def extract_rows(id, rows)
		table = @hash_vars[id]
		data = rows.map{|field| table[field]}
		return data
	end

	def process_attributes(attribs, delete_items, aggregated = false)
		parsed_attr = []
		if aggregated
			if !delete_items.nil? && !delete_items.empty?
				(1..delete_items.length).reverse_each do |ind|
					attribs.delete_at(1)
				end
			end
			attribs.first.length.times do |i|
				parsed_attr << attribs.map{|at| at[i]}
			end
		else
			attribs.each do |attrib|
				if !delete_items.nil? && !delete_items.empty?
					(1..delete_items.length).reverse_each do |ind|
						attrib.delete_at(ind)
					end
				end
				parsed_attr << attrib
			end			
		end
		return parsed_attr
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
			smp_attr: [],
			var_attr: [],			
			border: 1,
			cell_align: [],
			attrib: {}
		}
		options.merge!(user_options)
		table_attr = prepare_table_attribs(options[:attrib])
		array_data, _, _ = get_data(options)
		block.call(array_data) if !block.nil?
		rowspan, colspan = get_col_n_row_span(array_data)
		table_id = 'table_' + @count_objects.to_s
		@dt_tables << table_id if options[:styled] == 'dt'
		@bs_tables << table_id if options[:styled] == 'bs'
		tbody_tag = false
		html = "
		<table id=\"#{table_id}\" border=\"#{options[:border]}\" #{table_attr}>
			<% if options[:header] %>
				<thead>
			<% end %>
			<% array_data.each_with_index do |row, i| %>
				<% if options[:header] && i == 1 %>
					<tbody>
				<% end %>
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
				<% if i == 0 && options[:header] %>
					</thead>
				<% end %>
			<% end %>
			<% if options[:header] %>
				</tbody>
			<% end %>
		</table>
		"
		@count_objects += 1  
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
	def add_sample_attributes(data_structure, options)
		parsed_sample_attributes = {}
		options[:sample_attributes].each do |key, col|
			data, _, _ = get_data({id: options[:id], fields: [col], text: true})
			data.shift if options[:header]
			parsed_sample_attributes[key] = data.flatten 
		end
		data_structure['x'] = parsed_sample_attributes
	end

	def tree_from_file(file)
	        string_tree = File.open(file).read.gsub("\n", '')
	        return string_tree
	end

	def set_tree(options, config)
		tree = tree_from_file(options[:tree])
		if options[:treeBy] == 's'
			config['smpDendrogramNewick'] = tree
			config['samplesClustered'] = true
		elsif options[:treeBy] == 'v'
			config['varDendrogramNewick'] = tree
			config['variablesClustered'] = true
		end
	end

	def canvasXpress_main(user_options, block = nil)
		# Handle arguments
		#------------------------------------------
		options = {
			id: nil,
			fields: [],
			smp_attr: [],
			var_attr: [],
			segregate: [],
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
			sample_attributes: {},
			config: {},
			after_render: [],
			treeBy: 's'
		}
		options.merge!(user_options)
		config = {
			'toolbarType' => 'under',
			'xAxisTitle' => options[:x_label],
			'title' => options[:title]
		}
		if  !options[:tree].nil?
			set_tree(options, config)
		end
		config.merge!(options[:config])
		# Data manipulation
		#------------------------------------------
		no_data_string = ERB.new("<div width=\"#{options[:width]}\" height=\"#{options[:height]}\" > <p>NO DATA<p></div>").result(binding)
		data_array, smp_attr, var_attr = get_data(options)
		return no_data_string if data_array.empty?
		block.call(data_array) if !block.nil?
		object_id = "obj_#{@count_objects}_"
		raise("ID #{options[:id]} has not data") if data_array.nil?
		row_length = data_array.first.length
		samples = data_array.shift[1..row_length]
		return no_data_string if data_array.empty?
		vars = []
		data_array.each do |row|
			vars << row.shift
		end
		values = data_array

		x = {}
		z = {}
		add_canvas_attr(x, var_attr) if !var_attr.nil? && !var_attr.empty?
		add_canvas_attr(z, smp_attr) if !smp_attr.nil? && !smp_attr.empty?
		yield(options, config, samples, vars, values, object_id, x, z)
		# Build JSON objects and Javascript code
		#-----------------------------------------------
		@count_objects += 1
		data_structure = {
			'y' => {
				'vars' => vars,
				'smps' => samples,
				'data' => values
			},
			'x' => x,
			'z' => z
		}
		events = false
		info = false
		afterRender = options[:after_render]
		if options[:mod_data_structure] == 'boxplot'
			data_structure['y']['smps'] = nil
			data_structure.merge!({ 'x' => {'Factor' => samples}})
		elsif options[:mod_data_structure] == 'circular'
			data_structure.merge!({ 'z' => {'Ring' => options[:ring_assignation]}})
		end
		add_sample_attributes(data_structure, options) if !options[:sample_attributes].empty?
		extracode = "#{options[:extracode]}\n"
		extracode << segregate_data("C#{object_id}", options[:segregate]) if !options[:segregate].empty?
		extracode << "C#{object_id}.groupSamples(#{options[:group_samples]})\n" if !options[:group_samples].nil?
		plot_data = "
		var data = #{data_structure.to_json};
	        var conf = #{config.to_json}; 
        	var events = #{events.to_json};
	        var info = #{info.to_json};
	        var afterRender = #{afterRender.to_json};                
	        var C#{object_id} = new CanvasXpress(\"#{object_id}\", data, conf, events, info, afterRender);\n#{extracode}"
	        @plots_data << plot_data
        
	        responsive = ''
	        responsive = "responsive='true'" if options[:responsive]
		html = "<canvas  id=\"#{object_id}\" width=\"#{options[:width]}\" height=\"#{options[:height]}\" aspectRatio='1:1' #{responsive}></canvas>"
		return ERB.new(html).result(binding)
	end

	def segregate_data(obj_id, segregate)
		string =""
		segregate.each do |data_type, names|
			if data_type == :var
				string << "#{obj_id}.segregateVariables(#{names.inspect});\n"
			elsif data_type == :smp
				string << "#{obj_id}.segregateSamples(#{names.inspect});\n"
			end
		end
		return string
	end

	def add_canvas_attr(hash_attr, attr2add)
		attr2add.each do |attrs|
			attr_name = attrs.shift
			canvas_attr = []
			attrs.each{|at| canvas_attr << "#{attr_name} : #{at}" }
			hash_attr[attr_name] = canvas_attr
		end
	end

	def line(user_options = {}, &block)
		default_options = {
			row_names: true			
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			config['graphType'] = 'Line'	
		end
		return html_string
	end

	def stacked(user_options = {}, &block)
		default_options = {
			row_names: true,
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			config['graphType'] = 'Stacked'	
		end
		return html_string
	end
	
	def barplot(user_options = {}, &block)
		default_options = {
			row_names: true
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			config['graphType'] = 'Bar'
		end
		return html_string
	end

	def dotplot(user_options = {}, &block)
		default_options = {
			row_names: true,
			connect: false
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			config['graphType'] = 'Dotplot'
			if default_options[:connect]
				config['dotplotType'] = "stacked"
				config['connectBy'] = "Connect"
				z[:Connect] = Array.new(vars.length, 1)
			end
		end
		return html_string
	end

	def heatmap(user_options = {}, &block)
		default_options = {
			row_names: true
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			config['graphType'] = 'Heatmap'	
		end
		return html_string
	end

	def boxplot(user_options = {}, &block)
		default_options = {
			row_names: true,
			header: true
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			config['graphType'] = 'Boxplot'
			if default_options[:group].nil?
				options[:mod_data_structure] = 'boxplot'
			else
				if default_options[:group].class == String
					reshape(samples, vars, x, values)
					group = default_options[:group]
					series = 'factor'
				else
					series, group = default_options[:group]
				end
				if !config["groupingFactors"].nil? # if config is defined, we assume that the user set this property to the value that he/she desires
					if group.nil?
						config["groupingFactors"] = [series]
					else
						config["groupingFactors"] = [series, group]
					end
				end
				config["colorBy"] = series if !config["colorBy"].nil?
                config["segregateSamplesBy"] = [group] if !group.nil? && !config["segregateSamplesBy"].nil?
			end
			if options[:extracode].nil? && default_options[:group].nil?
				options[:extracode] = "C#{object_id}.groupSamples([\"Factor\"]);"
			end
		end
		return html_string
	end

	def reshape(samples, vars, x, values)
		item_names = samples.dup
		(vars.length - 1).times do |n|
			samples.concat(item_names.map{|i| i+"_#{n}"})
		end
		x.each do |factor, annotations|
			current_annotations = annotations.dup
			(vars.length - 1).times do 
				annotations.concat(current_annotations)
			end
		end
		series_annot = []
		vars.each do |var|
			item_names.each do 
				series_annot << var
			end
		end
		x['factor'] = series_annot
		vars.select!{|v| v.nil?}
		vars << 'vals'
		vals = values.flatten
		values.select!{|v| v.nil?}
		values << vals
	end

	def pie(user_options = {}, &block) 
		default_options = {
			transpose: false
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
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

	def corplot(user_options = {}, &block) 
		default_options = {
			transpose: false,
			correlationAxis: 'samples'
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			config['graphType'] = 'Correlation'
			config['correlationAxis'] = default_options[:correlationAxis]
		end
		return html_string
	end

	def sccater2D(user_options = {}, &block)
		default_options = {
			row_names: false,
			transpose: false
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			config['graphType'] = 'Scatter2D'
			config['xAxis'] = [samples.first] if config['xAxis'].nil?	
			config['yAxis']	= samples[1..samples.length-1] if config['yAxis'].nil?
			if default_options[:y_label].nil?
				config['yAxisTitle'] = 'y_axis'
			else
				config['yAxisTitle'] = default_options[:y_label]
			end
			if options[:regressionLine]
				options[:extracode] = "C#{object_id}.addRegressionLine();"
			end
		end
		return html_string
	end

	alias scatter2D sccater2D # Fix for wrong name method 

	def scatterbubble2D(user_options = {}, &block)
		default_options = {
			row_names: true,
			transpose: false
		}.merge!(user_options)
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			config['graphType'] = 'ScatterBubble2D'
			if options[:xAxis].nil?	
				config['xAxis'] = [samples[0]]
			else
				config['xAxis'] = options[:xAxis]
			end
			if options[:yAxis].nil?	
				config['yAxis'] = [samples[1]]
			else
				config['yAxis'] = options[:yAxis]
			end
			if options[:zAxis].nil?	
				config['zAxis'] = [samples[2]]
			else
				config['zAxis'] = options[:zAxis]
			end
			if default_options[:y_label].nil?
				config['yAxisTitle'] = 'y_axis'
			else
				config['yAxisTitle'] = default_options[:y_label]
			end
			if default_options[:z_label].nil?
				config['zAxisTitle'] = 'z_axis'
			else
				config['zAxisTitle'] = default_options[:z_label]
			end
			if !options[:upper_limit].nil? && !options[:lower_limit].nil? && !options[:ranges].nil?
				diff = (options[:upper_limit] - options[:lower_limit]).to_f/options[:ranges]
				sizes = Array.new(options[:ranges]) {|index| options[:lower_limit] + index * diff}
				config['sizes'] = sizes
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
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			options[:mod_data_structure] = 'circular'
			config['graphType'] = 'Circular'
			config['segregateVariablesBy'] = ['Ring']
			if default_options[:ringsType].empty?
				config['ringGraphType'] = Array.new(vars.length, 'heatmap')
			else
				config['ringGraphType'] = default_options[:ringsType]
			end
			if default_options[:ringsWeight].empty?
				size = 100/vars.length
				config['ringGraphWeight'] = Array.new(vars.length, size)
			else
				config['ringGraphWeight'] = default_options[:ringsWeight]
			end
			if default_options[:ring_assignation].empty?
				options[:ring_assignation] = Array.new(vars.length) {|index| (index + 1).to_s}
			else
				options[:ring_assignation] = default_options[:ring_assignation].map{|item| item.to_s}
			end
			if !default_options[:links].nil?
				if !@hash_vars[default_options[:links]].nil? && !@hash_vars[default_options[:links]].empty?
					link_data, _, _ = get_data({id: default_options[:links], fields: [], add_header_row_names: false, text: true, transpose: false}) 
					config['connections'] = assign_rgb(link_data)
				end
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

	def circular_genome(user_options = {}, &block)
		default_options = {}.merge!(user_options)
		coordinates = user_options[:genomic_coordinates]
		html_string = canvasXpress_main(default_options, block) do |options, config, samples, vars, values, object_id, x, z|
			config['graphType'] = 'Circular'
			config["arcSegmentsSeparation"] = 3
    	config["colorScheme"] = "Tableau"
    	config["colors"] = ["#332288","#6699CC","#88CCEE","#44AA99","#117733","#999933","#DDCC77","#661100","#CC6677","#AA4466","#882255","#AA4499"]
			config["showIdeogram"] = true
			chr = []
			pos = []
			tags2remove = []
			vars.each_with_index do |var, i|
				coord = coordinates[var]
				if !coord.nil?
					tag = coord.first.gsub(/[^\dXY]/,'')
					if tag == 'X' || tag == 'Y' || (tag.to_i > 0 && tag.to_i <= 22)
						chr << coord.first.gsub(/[^\dXY]/,'')
						pos << coord.last - 1
					else
						tags2remove << i
					end
				else
					tags2remove << i
				end
			end
			tags2remove.reverse_each{|i| ent = vars.delete_at(i); warn("Feature #{ent} has not valid coordinates")} # Remove entities with invalid coordinates
			z['chr'] = chr
			z['pos'] = pos
		end
		return html_string
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

	def embed_pdf(pdf_file, pdf_attribs = nil)
		pdf_content = File.open(pdf_file).read
		pdf_base64 = Base64.encode64(pdf_content)
		pdf_string = "<embed #{pdf_attribs} src=\"data:application/pdf;base64,#{pdf_base64}\" type=\"application/pdf\"></embed>"
		return pdf_string
	end
end
