require File.join(File.dirname(__FILE__), "..", "lib/ojdbc7-12.1.0.2.0.jar")
Sequel::Model.plugin(:schema)
Sequel::Model.raise_on_save_failure = false # Do not throw exceptions on failure
Sequel::Model.db = case Padrino.env
  when :development then Sequel.connect("B2B_URI")
  when :production  then Sequel.connect("B2B_URI")
  when :test        then Sequel.connect("B2B_URI")
  when :cte         then Sequel.connect("B2B_URI")
end
