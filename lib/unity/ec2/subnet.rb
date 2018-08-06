class Unity::EC2::Subnet
  
  attr_reader :manager
  
  def initialize(manager)
    @manager = manager
  end
  
  def list(vpc)
    list = []

    # filter the collection to just nanobox instances
    filter = [
      {'Name' => 'vpc-id',      'Value' => vpc[:id]},
      {'Name' => 'tag:Nanobox', 'Value' => 'true'}
    ]
    
    # query the api
    res = manager.DescribeSubnets('Filter' => filter)
    
    # extract the collection
    subnets = res['DescribeSubnetsResponse']['subnetSet']
    
    # short-circuit if the collection is empty
    return [] if subnets.nil?
    
    # subnets might not be a collection, but a single item
    collection = begin
      if subnets['item'].is_a? Array
        subnets['item']
      else
        [subnets['item']]
      end
    end
    
    # grab the subnets and process them
    collection.each do |subnet|
      list << process(subnet)
    end

    list
  end
  
  def show(vpc, name)
    list(vpc).each do |subnet|
      if subnet[:name] == name
        return subnet
      end
    end
    
    # return nil if we can't find it
    nil
  end
  
  def create(vpc, name, public=true)
    # short-circuit if this already exists
    existing = show(vpc, name)
    if existing
      return existing
    end
    
    # create subnet
    subnet = create_subnet(vpc, name)
    
    # tag subnet
    tag_subnet(vpc, subnet['subnetId'], name)
    
    # modify attributes
    set_public(subnet["subnetId"]) if public
    
    show(vpc, name)
  end
  
  protected
  
  def create_subnet(vpc, name)
    # grab the subnet ints
    vpc_subnet_int  = vpc[:subnet][/.+\.(.+)\..+\./, 1]
    subnet_int      = subnet_int(vpc[:id])
    
    # create the subnet
    res = manager.CreateSubnet(
      'VpcId'     => vpc[:id],
      'CidrBlock' => "10.#{vpc_subnet_int}.#{subnet_int}.0/21"
    )
    
    # extract the response
    res["CreateSubnetResponse"]["subnet"]
  end
  
  def tag_subnet(vpc, id, name)
    # tag the subnet
    res = manager.CreateTags(
      'ResourceId'  => id,
      'Tag' => [
        {
          'Key' => 'Nanobox',
          'Value' => 'true'
        },
        {
          'Key' => 'Name',
          'Value' => "Nanobox-Unity-#{vpc[:name]}-#{name}"
        },
        {
          'Key' => 'ZoneName',
          'Value' => name
        }
      ]
    )
  end
  
  def subnet_int(vpc_id)
    # this could be more advanced. Essentially, let's just see how many
    # subnets exist, and add one
    
    # filter the collection to just the vpc
    filter = [
      {'Name' => 'vpc-id', 'Value' => vpc_id},
    ]
    
    res = manager.DescribeSubnets('Filter' => filter)

    # extract the collection
    subnets = res['DescribeSubnetsResponse']['subnetSet']
    
    # short-circuit if the collection is empty
    return 8 if subnets.nil?
    
    # subnets might not be a collection, but a single item
    collection = begin
      if subnets['item'].is_a? Array
        subnets['item']
      else
        [subnets['item']]
      end
    end
    
    (collection.count || 0) * 8 + 8
  end
  
  def set_public(subnet_id)
    res = manager.ModifySubnetAttribute(
      'SubnetId'  => subnet_id,
      'MapPublicIpOnLaunch.Value' => 'true'
    )
  end
  
  def process(data)
    {
      id:     data["subnetId"],
      name:   (process_tag(data['tagSet']['item'], 'ZoneName') rescue 'unknown'),
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
