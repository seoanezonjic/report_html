#! /usr/bin/env ruby

#require 'math'
require 'optparse'
##################################################################################################
## METHODS
##################################################################################################
def concat_data(table, selected_data)
    table.each_with_index do |row, index|
        row.concat(selected_data[index])
    end
end

def index_data(table, selected_data, col_index, range, null_string)
    efective_data_length = selected_data.first.length - 1
    null_data = Array.new(efective_data_length, null_string)
    temp_range = []    
    table.each_with_index do |row, index|
        match = false
        selected_data.each_with_index do |sel_data, sel_index|
            if row[0] == sel_data[col_index]
                data = selected_data.delete_at(sel_index)
                data.delete_at(col_index)
                temp_range = [range, data] if range > 0
                row.concat(data)
                match = true
                break
            end
        end
        if !match
            if temp_range.empty? # No match then we aggreagate null data
                row.concat(null_data)
            elsif temp_range.first > 0 # There is data that must be repeated in a number of rows defined by range
                iterations = temp_range.first
                row.concat(temp_range.last)
                iterations -= 1
                if iterations == 0
                    temp_range = []
                else
                    temp_range[0] = iterations
                end 
            end
        else
            selected_data.compact!
        end
    end
end
#################################################################################################
## INPUT PARSING
#################################################################################################
options = {}

optparse = OptionParser.new do |opts|
        options[:files] = []
        opts.on( '-i', '--input_file FILES', 'Files from extract data' ) do |data|
            options[:files] = data.split(',')
        end

        options[:header] = []
        opts.on( '-H', '--header STRING', 'Comma separated string with the name of each column on final file' ) do |data|
            options[:header] = data.split(',')
        end

        options[:fields] = []
        opts.on( '-f', '--fields INTEGERS', 'Positions of colums to extract data' ) do |data|
            options[:fields] = data.split(',').map { |e| e.split(';').map{|i| i.to_i - 1} }
        end

        options[:col_indexes] = []
        opts.on( '-c', '--col_index INTEGERS', 'Position of the column to use for index operations within the specified fields. 0 indicates no index and perform a simple addition' ) do |data|
            options[:col_indexes] = data.split(',').map{|i| i.to_i - 1}
        end

        options[:range] = []
        opts.on( '-r', '--range INTEGERS', 'It is assumed that input data es binned and this integer specifies how many positions must be labeled with the bin data' ) do |data|
            options[:range] = data.split(',').map{|i| i.to_i - 1}
        end

        options[:null] = nil
        opts.on( '-n', '--null_value STRING', 'String to use when a field is empty' ) do |data|
            options[:null] = data
        end

        opts.banner = "Usage: table_header.rb -t tabulated_file \n\n"

        # This displays the help screen
        opts.on( '-h', '--help', 'Display this screen' ) do
                puts opts
                exit
        end

end # End opts

# parse options and remove from ARGV
optparse.parse!

table = []
options[:files].each_with_index do |file, n|
    fields = options[:fields][n]
    col_index = options[:col_indexes][n]
    range = options[:range][n]
    if File.exists?(file)
        selected_data = []
        File.open(file).each do |line|
            line.chomp!
            data = line.split("\t")
            selected_data << fields.map{|f| data[f]}
        end
        if table.empty?
            table = selected_data
        elsif selected_data.empty?
            concat_data(table, Array.new(table.length, [options[:null]]))
        else
            if col_index == -1
                concat_data(table, selected_data)
            else
                index_data(table, selected_data, col_index, range, options[:null])
            end
        end
    else
        raise "File #{file} not exists"
    end
end
puts options[:header].join("\t") if !options[:header].empty?
table.each do |row|
    puts row.join("\t")
end
