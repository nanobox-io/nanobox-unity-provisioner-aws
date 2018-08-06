class Unity::EC2::Base
  
  attr_reader :manager
  attr_reader :logger
  
  def initialize(manager, logger, log_prefix='')
    @manager = manager
    @logger  = logger
  end
  
  protected
  
  def log(message)
    logger.info "#{log_prefix}#{message}"
  end
  
  def warn(message)
    logger.warn "#{log_prefix}#{message}"
  end
  
  def err(message)
    logger.error "#{log_prefix}#{message}"
  end
  
end
