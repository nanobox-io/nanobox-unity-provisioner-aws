class Unity::Logger::Stdout < Unity::Logger::Base
  
  def info(message)
    puts message
  end
  
  def warn(message)
    # todo: add yellow
    puts message
  end
  
  def error(message)
    # todo: add red
    puts message
  end
  
end
