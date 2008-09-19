require 'rails_generator'
require 'getoptlong'
require 'rexml/document'

class DbdesignerMigrationGenerator < Rails::Generator::NamedBase

  attr_accessor :migration_name, :tables, :relations

  def manifest
    @migration_name = class_name

    if args.include? "except" and args.include? "only"
      raise "It is not possible to use 'except' and 'only' parameters togheter. Try again."
    end

    @tables = []
    track = nil
    args.each do |arg|
      @tables << arg unless track.nil?
      arg = arg.to_sym
      track = arg if arg.eql? :except or arg.eql? :only
    end

    if track.eql? :except
      puts "Ignoring table(s) #{@tables.join(',')}\n"
      DBDesignerMigration::Model.ignore_tables = @tables 
    elsif track.eql? :only
      puts "Processing only table(s) #{@tables.join(',')}\n"
      DBDesignerMigration::Model.only_tables = @tables 
    end

    begin
      dbmodel_path = File.join('db', 'dbdesigner_model.xml')
      unless File.exist?(dbmodel_path)
        raise "Could not find any database model in db/dbdesigner_model.xml"
      end

      xml = REXML::Document.new(File.open(dbmodel_path))

      # Verify that this is a DBDesigner XML file
      if xml.elements['DBMODEL'].nil? or xml.elements['DBMODEL'].attributes["Version"] != '4.0'
        raise "File '#{dbmodel_path}' is not a DBDesigner 4 XML file. Skipping..."
      else
        puts "Reading the datamodel XML (#{dbmodel_path}) from DBDesigner..." if not $silent
        xml.elements.each("//DATATYPE") { |d| DBDesignerMigration::Model.add_datatype(d) }
        xml.elements.each("//TABLE") { |t| DBDesignerMigration::Model.add_table(t) }
        xml.elements.each("//RELATION") { |r| DBDesignerMigration::Model.add_relation(r) }
      end
    rescue Exception => ex
      puts ex.message
      puts ex.backtrace.find {|str| str =~ /\.rb/ } || ""
      exit(1)
    end

    @tables = DBDesignerMigration::Model.tables
    @tables.delete_if {|table| table.ignore? }
    
    @relations = DBDesignerMigration::Model.relations
    @relations.delete_if {|relation| relation.from_table.ignore? or relation.to_table.ignore? }

    if @tables.empty? and @relations.empty?
      puts "Nothing to do!"
      exit(0)
    end

    record do |m|
      m.directory File.join('db')
      m.migration_template 'dbdesigner_migration.rb',"db/migrate", :migration_file_name => "#{file_path}"
    end
  end

end

module DBDesignerMigration

  class Model
    @datatypes = []
    @tables = []
    @relations = []
    @only_tables = nil
    @ignore_tables = nil
 
    def self.only_tables=(tables)
      @only_tables = tables
    end

    def self.ignore_tables=(tables)
      @ignore_tables = tables
    end
 
    def self.datatypes
      @datatypes
    end

    def self.tables
      @tables
    end
    
    def self.relations
      @relations
    end

    def self.add_datatype(xmlobj)
      id = xmlobj.attributes['ID']
      name = xmlobj.attributes['TypeName']

      if(@datatypes.find {|d| d.id == id})
        raise "Duplicate datatype definition on #{name}"
      end

      @datatypes << Datatype.new(xmlobj)
    end

    def self.add_table(xmlobj)
      id = xmlobj.attributes['ID']
      name = xmlobj.attributes['TableName']

      if(@tables.find {|t| t.id == id})
        raise "Duplicate table definition on #{name}"
      end

      @tables << Table.new(xmlobj)
    end

    def self.add_relation(xmlobj)
      id = xmlobj.attributes['ID']
      name = xmlobj.attributes['RelationName']

      if(@relations.find {|t| t.id == id})
        raise "Duplicate table definition on #{name}"
      end

      @relations << Relation.new(xmlobj)
    end

=begin
PREPARED TO USE FOR MODELS

    def self.add_relationship(r)
      src_table = @tables.find {|t| t.id == r.attributes['SrcTable']}
      dest_table = @tables.find {|t| t.id == r.attributes['DestTable']}

      relationship = r.attributes['RelationName']
      if relationship =~ /\s*habtm\s*:(\w+)/
        relationship = "  has_and_belongs_to_many :#{$1}"
      else
        # If we are inserting the other side of a relationship (non-habtm),
        # we need to mirror the relationship.
        # NOTE: in the DB model, links should be labeled 'has_one' or 'has_many'
        #       not 'belongs_to' since that label is ambiguous 1:1 or 1:n
        if relationship =~ /has_one/ or relationship =~ /has_many/
          dest_table.relationships << '  belongs_to :' + src_table.name
        else relationship !~ /has_and_belongs_to_many/
          puts "error: relationships must be labeled 'has_one :x', 'has_many :x', 'habtm :x' or 'has_and_belongs_to_many :x'"
          return
        end
        relationship = '  ' + relationship
      end
      src_table.relationships << relationship
    end
=end    
  def self.format_options(options)
    return if options.empty?

    formatted = ""
    options.each do |k,v|
      if v.is_a? Symbol
        formatted << ", :#{k} => :#{v}"
      elsif v.is_a? String
        formatted << ", :#{k} => '#{v}'"
      else
        formatted << ", :#{k} => #{v}"
      end
    end

    formatted
  end
  
  protected
    def self.include_table?(table_name)
      return ((!@only_tables.nil? and @only_tables.include? table_name) or (@only_tables.nil? and @ignore_tables.nil?) or (!@ignore_tables.nil? and !@ignore_tables.include? table_name))
    end
  end
  
  class Datatype
    attr_accessor :id, :name, :description, :physical

    def initialize(xmlobj)
      @id = xmlobj.attributes['ID']
      @name = @physical = xmlobj.attributes['TypeName'].downcase
      @description = xmlobj.attributes['Description']
      @physical = xmlobj.attributes['PhysicalTypeName'].downcase if not xmlobj.attributes['PhysicalTypeName'].empty?
    end
  end

  class Table
    attr_accessor :id, :name, :comments, :columns, :indexes, :relationships, :options, :capitalized

    alias_method :fields, :columns

    def initialize(xmlobj)
      @id = xmlobj.attributes['ID']
      @name = xmlobj.attributes['Tablename']
      @capitalized = []
      @name.split("_").each { |c| @capitalized << c.capitalize }
      @capitalized = @capitalized.join
      @comments = xmlobj.attributes['Comments'].split("\\n")
      @columns = []
      @indexes = []
      @relationships = []
      @options = {}
      @process = ((Model.include_table? @name) and (@comments.empty? or @comments.first.downcase.strip != "ignore"))

      if @name == @name.singularize
          puts "Warning: table #{@name} is not in plural\n"
      end

      xmlobj.elements.each("COLUMNS/COLUMN") { |c| self.add_column(c) }
      xmlobj.elements.each("INDICES/INDEX") { |i| self.add_index(i) }
    end

    def process?
      @process
    end

    def ignore?
      !@process
    end

    def add_column(xmlobj)
      id = xmlobj.attributes['ID']
      name = xmlobj.attributes['ColName']
      if("id" == name.downcase)
        return
      end

      if(@columns.find {|c| c.id == id})
        raise "Duplicate column definition on #{self.name} #{name}"
      end
      column = Column.new(xmlobj)
      @columns.push(column)
    end

    def add_index(xmlobj)
      id = xmlobj.attributes['ID']
      name = xmlobj.attributes['IndexName']

      xmlobj.elements.each("INDEXCOLUMNS/INDEXCOLUMN") { |i| 
	      if(self.columns.find {|c| c.id == i.attributes['idColumn']}.nil?)
	        return
	      end
      }

      if(@indexes.find {|i| i.id == id})
        raise "Duplicate index definition on #{self.name} #{name} (#{id})"
      end
      index = Index.new(self, xmlobj)
      @indexes.push(index)
    end

  end
  
  class Column
    attr_accessor :id, :name, :datatype, :params, :notnull, :default, :comments, :options

    def initialize(xmlobj)
      @id = xmlobj.attributes['ID']
      @name = xmlobj.attributes['ColName']
      @datatype = Model.datatypes.find {|c| c.id == xmlobj.attributes['idDatatype']}.physical
      @params = xmlobj.attributes['DatatypeParams']
      @notnull = xmlobj.attributes['NotNull']
      @default = xmlobj.attributes['DefaultValue']
      @comments = xmlobj.attributes['Comments']
      @comments = "# #{@comments.split("\\n").join(', ')}" unless @comments.empty?

      options = {}
      options['default'] = @default unless @default.empty?
      options['null'] = ("1" == @notnull) ? false : true
      if not @params.empty?
        if float = /\(([0-9]+),([0-9]+)\)/.match(@params)
          options['precision'] = float[1].to_i 
          options['scale'] = float[2].to_i
        else
          options['limit'] = /\(([0-9]*)\)/.match(@params)[1].to_i
        end
      end
#      @options['limit'] = (eval(@params) rescue nil) if not @params.empty?

      @options = Model.format_options(options)

    end

  end
  
  class Index
    attr_accessor :id, :table, :name, :columns, :unique, :options
    
    def initialize(table, xmlobj)
      @id = xmlobj.attributes['ID']
      @name = xmlobj.attributes['IndexName']
      @table = table.name
      columns = Array.new
      xmlobj.elements.each("INDEXCOLUMNS/INDEXCOLUMN") { |i| 
        columns << table.columns.find {|c| c.id == i.attributes['idColumn']}.name
      }
      @columns = "[:#{columns.join(',:')}]" unless columns.nil?
      @unique = xmlobj.attributes['IndexKind'] == "2"
      if @unique
        options = {}
        options['unique'] = @unique
        @options = Model.format_options(options)
      end
    end
  end

  class Relation
    attr_accessor :id, :name, :from_table, :from_column, :to_table, :to_column, :options

    def initialize(xmlobj)
      # DBDesigner codes      
      # 0 = restrict
      # 1 = cascade
      # 2 = set null
      # 3 = no action
      # 4 = set default
      @dbdesigner_codes = ['restrict','cascade','set null','no action','set default']

      @id = xmlobj.attributes['ID']
      @name = xmlobj.attributes['RelationName'].downcase
      @from_table = Model.tables.find {|t| t.id == xmlobj.attributes['DestTable']}
      @to_table = Model.tables.find {|t| t.id == xmlobj.attributes['SrcTable']}
      fields = xmlobj.attributes['FKFields'].strip.split("=")
      @from_column = fields[1].match(/([a-zA-Z_-])*/).to_s
      @to_column = fields[0].match(/([a-zA-Z_-])*/).to_s

      options = {}

      on_delete = xmlobj.attributes['RefDef'].match(/OnDelete=([0-4]{1})/)
      if on_delete
        @on_delete = @dbdesigner_codes[on_delete[1].to_i]
        options['on_delete'] = @on_delete
      end

      on_update = xmlobj.attributes['RefDef'].match(/OnUpdate=([0-4]{1})/)
      if on_update
        @on_update = @dbdesigner_codes[on_update[1].to_i]
        options['on_update'] = @on_update
      end
      @options = Model.format_options(options)
      
      if(@from_table.process? and @to_table.process?)
        if (@from_column == 'parent_id' and @from_table.name != @to_table.name) or
           (@from_column != 'parent_id' and @from_column != "#{@to_table.name.singularize}_#{@to_column}")
            puts "Warning: foreign_key #{@from_table.name}.#{@from_column} => #{@to_table.name}.#{@to_column}\n"
        end
      end
    end
  end

end

