# Ruby 3.4: JSON::Ext::Parser.new expects keyword args; json gem 1.8.6 passes a hash.
# Patch JSON.parse to use **opts so Parser.new(source, **opts) is used.
module JSON
  module_function

  def parse(source, opts = {})
    Parser.new(source, **opts).parse
  end

  def parse!(source, opts = {})
    opts = {
      max_nesting: false,
      allow_nan: true
    }.merge(opts)
    Parser.new(source, **opts).parse
  end
end
