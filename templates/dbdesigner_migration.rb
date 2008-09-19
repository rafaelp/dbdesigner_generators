require 'postgresql_migrations'
class <%= migration_name.underscore.camelize %> < ActiveRecord::Migration
  def self.up<% tables.each do |table| -%>
<% table.comments.each do |comment| -%>
      <%= "\# #{comment}" %>
<% end -%>

    create_table "<%= table.name %>"<% table.options.each do |k,v| %>, :<%= k %> => <%= v %><% end %>, :force => true do |t|
<% table.fields.each do |field| -%>
      t.<%= field.datatype %> "<%= field.name %>" <%= field.options %> <%= field.comments %>
<% end -%>
      t.timestamps
    end

<% table.indexes.sort_by {|index| index.table.to_s}.each do |index| -%>
    <%= "add_index :#{index.table}, #{index.columns} #{index.options}" %>
<% end -%>
<% end -%>

<% relations.each do |relation| -%>
    <%= "add_foreign_key :#{relation.from_table.name}, :#{relation.from_column}, :#{relation.to_table.name}, :#{relation.to_column} #{relation.options}" %>
<% end -%>
  end

  def self.down
<% relations.each do |relation| -%>
    <%= "remove_foreign_key :#{relation.from_table.name}, :#{relation.from_column}" %>
<% end -%>
<% tables.sort_by {|table| table.name.to_s }.each do |table| -%>
<% table.indexes.sort_by {|index| index.table.to_s}.each do |index| -%>
    <%= "remove_index :#{index.table}, #{index.columns}" %>
<% end -%>
    <%= "drop_table :#{table.name}" %>
<% end -%>
  end
end

