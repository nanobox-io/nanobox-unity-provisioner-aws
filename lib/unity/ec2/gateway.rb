class Unity::EC2::Gateway < Unity::EC2::Base
  
  def list
    list = []

    # filter the collection to just nanobox instances
    filter = [{'Name'  => 'tag:Nanobox', 'Value' => 'true'}]

    # query the api
    res = manager.DescribeInternetGateways('Filter' => filter)

    # extract the instance collection
    gateways = res["DescribeInternetGatewaysResponse"]["internetGatewaySet"]

    # short-circuit if the collection is empty
    return [] if gateways.nil?

    # gateways might not be a collection, but a single item
    collection = begin
      if gateways['item'].is_a? Array
        gateways['item']
      else
        [gateways['item']]
      end
    end

    # grab the gateways and process them
    collection.each do |gateway|
      list << process(gateway)
    end

    list
  end
  
  def show(name)
    list.each do |gateway|
      if gateway[:name] == name
        return gateway
      end
    end
    
    # return nil if we can't find it
    nil
  end
  
  def create(name)
    # short-circuit if this already exists
    existing = show(name)
    if existing
      return existing
    end
    
    # create the gateway
    gateway = create_gateway(name)
    
    # tag the gateway
    tag_gateway(gateway['internetGatewayId'], name)
    
    # process the gateway
    process(gateway)
  end
  
  def attach(vpc_id, id)
    # attach the gateway to the vpc
    res = manager.AttachInternetGateway(
      'InternetGatewayId' => id,
      'VpcId'             => vpc_id
    )
    
    # find out if it was attached
    res["AttachInternetGatewayResponse"]["return"]
  end
  
  protected
  
  def create_gateway(name)
    # create an internet gateway
    res = manager.CreateInternetGateway()
    
    # extract the response
    res["CreateInternetGatewayResponse"]["internetGateway"]
  end
  
  def tag_gateway(id, name)
    # tag the vpc
    res = manager.CreateTags(
      'ResourceId'  => id,
      'Tag' => [
        {
          'Key' => 'Nanobox',
          'Value' => 'true'
        },
        {
          'Key' => 'Name',
          'Value' => "Nanobox-Unity-#{name}"
        },
        {
          'Key' => 'EnvName',
          'Value' => name
        }
      ]
    )
  end
  
  def process(data)
    {
      id:     data["internetGatewayId"],
      name:   (process_tag(data['tagSet']['item'], 'EnvName') rescue 'unknown'),
    }
  end
  
  def process_tag(tags, key)
    tags.each do |tag|
      if tag['key'] == key
        return tag['value']
      end
    end
    ''
  end
  
end
