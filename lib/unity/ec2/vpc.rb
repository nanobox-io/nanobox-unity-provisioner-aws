class Unity::EC2::VPC < Unity::EC2::Base
  
  def list
    list = []

    # filter the collection to just nanobox instances
    filter = [{'Name'  => 'tag:Nanobox', 'Value' => 'true'}]

    # query the api
    res = manager.DescribeVpcs('Filter' => filter)

    # extract the instance collection
    vpcs = res["DescribeVpcsResponse"]["vpcSet"]

    # short-circuit if the collection is empty
    return [] if vpcs.nil?

    # vpcs might not be a collection, but a single item
    collection = begin
      if vpcs['item'].is_a? Array
        vpcs['item']
      else
        [vpcs['item']]
      end
    end

    # grab the vpcs and process them
    collection.each do |vpc|
      list << process(vpc)
    end

    list
  end
  
  def show(name)
    list.each do |vpc|
      if vpc[:name] == name
        return vpc
      end
    end
    
    # return nil if we can't find it
    nil
  end
  
  def create(name)
    # short-circuit if this already exists
    existing = show(name)
    if existing
      logger.info("VPC '#{name}' already exists")
      return existing
    end
    
    # create the vpc
    logger.info("Creating VPC '#{name}'")
    vpc = create_vpc
    
    # tag the vpc
    logger.info("Tagging VPC '#{name}'")
    tag_vpc(vpc['vpcId'], name)
    
    show(name)
  end
  
  protected
  
  def create_vpc
    cidr = "10.#{subnet_int}.0.0/16"
    logger.info "Found available network #{cidr}"
    
    # create the vpc with a unique cidr block
    res = manager.CreateVpc(
      'CidrBlock' => cidr
    )
    
    # extract the response
    res["CreateVpcResponse"]["vpc"]
  end
  
  def tag_vpc(id, name)
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
  
  def subnet_int
    # this could be more advanced. Essentially, let's just see how many
    # vpcs exist, and add one
    res = manager.DescribeVpcs()

    # extract the instance collection
    vpcs = res["DescribeVpcsResponse"]["vpcSet"]
    
    collection = begin
      if vpcs['item'].is_a? Array
        vpcs['item']
      else
        [vpcs['item']]
      end
    end
    
    (collection.count || 0) + 1
  end
  
  def process(data)
    {
      id:     data["vpcId"],
      name:   (process_tag(data['tagSet']['item'], 'EnvName') rescue 'unknown'),
      subnet: data["cidrBlock"]
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
