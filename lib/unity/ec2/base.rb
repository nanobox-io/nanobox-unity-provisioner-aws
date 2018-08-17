class Unity::EC2::Base
  
  attr_reader :manager
  attr_reader :logger
  
  def initialize(manager, logger, log_prefix='')
    @manager = manager
    @logger  = logger
  end
  
  protected
  
  def process_tag(tags, key)
    tags.each do |tag|
      if tag['key'] == key
        return tag['value']
      end
    end
    ''
  end
  
end
