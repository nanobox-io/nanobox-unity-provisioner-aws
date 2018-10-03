class Unity::EC2::Subnet < Unity::EC2::Base
  
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
  
  def show_all(vpc, name)
    list(vpc).keep_if do |subnet|
      subnet[:name] =~ /^#{name}/
    end
  end
  
  def create(vpc, name, zones, public=true)
    zones.map do |zone|
      # update the name to include the zone
      zone_id = zone[:name].split('-').last
      
      # append the name
      fq_name = "#{name}-#{zone_id}"
      
      # short-circuit if this already exists
      existing = show(vpc, fq_name)
      if existing
        logger.info "Subnet '#{fq_name}' already exists"
      else
        # create subnet
        logger.info "Creating subnet '#{fq_name}'"
        subnet = create_subnet(vpc, zone, fq_name)
        
        # tag subnet
        logger.info "Tagging subnet '#{fq_name}'"
        tag_subnet(vpc, subnet['subnetId'], fq_name)
        
        # modify attributes
        if public
          logger.info "Enabling public interfaces on subnet"
          set_public(subnet["subnetId"])
        end
      end
      
      # return the subnet
      show(vpc, fq_name)
    end
  end
  
  protected
  
  def create_subnet(vpc, zone, name)
    # grab the subnet ints
    vpc_subnet_int = vpc[:subnet][/.+\.(.+)\..+\./, 1]
    subnet_int     = subnet_int(vpc[:id])
    cidr           = "10.#{vpc_subnet_int}.#{subnet_int}.0/21"
    
    logger.info "Found available subnet #{cidr}"
    
    # create the subnet
    res = manager.CreateSubnet(
      'VpcId'     => vpc[:id],
      'CidrBlock' => cidr,
      'AvailabilityZone' => zone[:name]
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
