require 'erb'
require 'fileutils'
require 'json'

JS_FOLDER = File.expand_path(File.join(__FILE__, '..', '..', '..', 'js'))

class Report_html
	def initialize(hash_vars, title = "report")
		@all_report = ""
		@title = title
		@hash_vars = hash_vars
		@plots_data = []
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
	def table(data_id)
		html = "
		<table>
			<% @hash_vars[data_id].each do |row| %>
				<tr>
					<% row.each do |cell| %>
						<td><%= cell %></td>
					<% end %>
				<tr>
			<% end %>
		</table>
		"
		return ERB.new(html).result(binding)
	end

	def canvasXpress_main(user_options, data_format = 'one_axis')
		# Handle arguments
		#------------------------------------------
		options = {
			id: nil,
			var_name: [],
			height: 600,
			width: 600,
			header: false,
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
		data_array = @hash_vars[options[:id]]
		samples = nil
		values = []
		if data_format == 'one_axis'
			if options[:header] 
				# We don't use shift to avoid the corruption of the table if the same table is used twice
				header = data_array.first
				header = header[1..header.length-1] #discards name of columns ids
				options[:var_name] = header
			end
			ncols = data_array.first.length
			nrows = data_array.length
			ncols.times do |n|
				if n == 0
					samples = data_array.map{|item| item[n]}
					samples.shift if options[:header] # Discard col header from row ids
				else
					vals = data_array.map{|item| item[n]}
					vals.shift if options[:header] # Discard col header from numeric values
					values << vals
				end
			end
		elsif data_format == 'sccater2D'
			if !options[:header]
				samples = ['x']
				(data_array.first.length - 1).times do |n|
					samples << "smp#{n}"
				end
			else
				samples = data_array.first
				data_array = data_array[1..data_array.length-1]
			end
			values = data_array
		end

		options.delete(:var_name) if options[:var_name].empty? || !options[:header]
		yield(options, config, samples, values)

		# Build JSON objects and Javascript code
		#-----------------------------------------------
		data_structure = {
			'y' => {
				'vars' => options[:var_name],
				'smps' => samples,
				'data' => values
			}
		}
		object_id = options[:id].to_s + '_' + config['graphType']
		plot_data = "
		var data = #{data_structure.to_json};
        var conf = #{config.to_json};                 
        var C#{object_id} = new CanvasXpress(\"#{object_id}\", data, conf);\n"
        @plots_data << plot_data
        
		html = "<canvas  id=\"#{object_id}\" width=\"#{options[:width]}\" height=\"#{options[:height]}\" aspectRatio='1:1' responsive='true'></canvas>"
		return ERB.new(html).result(binding)
	end

	def line(user_options = {})
		html_string = canvasXpress_main(user_options) do |options, config, samples, values|
			config['graphType'] = 'Line'	
		end
		return html_string
	end

	def stacked(user_options = {})
		html_string = canvasXpress_main(user_options) do |options, config, samples, values|
			config['graphType'] = 'Stacked'	
		end
		return html_string
	end
	
	def barplot(user_options = {})
		html_string = canvasXpress_main(user_options) do |options, config, samples, values|
			config['graphType'] = 'Bar'	
		end
		return html_string
	end

	def pie(user_options = {})
		html_string = canvasXpress_main(user_options) do |options, config, samples, values|
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

	def sccater2D(user_options = {})
		html_string = canvasXpress_main(user_options, 'sccater2D') do |options, config, samples, values|
			config['graphType'] = 'Scatter2D'
			config['xAxis'] = [samples.first]	
			config['yAxis']	= samples[1..samples.length-1]
			if user_options[:y_label].nil?
				config['yAxisTitle'] = 'y_axis'
			else
				config['yAxisTitle'] = user_options[:y_label]
			end
		end
		return html_string
	end

end