class Unity::EC2::SecurityGroup < Unity::EC2::Base
  
  def list(vpc)
    list = []
    
    # filter the collection to just nanobox instances
    filter = [
      {'Name'  => 'vpc-id',       'Value' => vpc[:id]},
      {'Name'  => 'tag:Nanobox',  'Value' => 'true'}
    ]
    
    # query the api
    res = manager.DescribeSecurityGroups('Filter' => filter)
    
    # extract the collection
    groups = res['DescribeSecurityGroupsResponse']['securityGroupInfo']
    
    return [] if groups.nil?
    
    # groups might not be a collection, but a single item
    collection = begin
      if groups['item'].is_a? Array
        groups['item']
      else
        [groups['item']]
      end
    end
    
    # grab the groups and process them
    collection.each do |group|
      list << process(group)
    end

    list
  end
  
  def show(vpc, name)
    list(vpc).each do |group|
      if group[:name] == name
        return group
      end
    end
    
    # return nil if we can't find it
    nil
  end
  
  def create_dmz(vpc)
    # short-circuit if this already exists
    existing = show(vpc, 'DMZ')
    if existing
      logger.info "Security Group 'DMZ' already exists"
      return existing
    end
    
    # create the security group
    logger.info "Creating the Security Group 'DMZ'"
    sg = create_group(vpc, 'DMZ')
    
    # extract the ID for convenience 
    sg_id = sg['groupId']
    
    # tag the security group with a name
    logger.info "Tagging Security Group"
    tag_group(vpc, sg_id, 'DMZ')
    
    # create inbound rules
    # 
    logger.info "Adding ingress rules to DMZ"
    # allow ssh
    add_rule sg_id, '6', 22, 22, '0.0.0.0/0'
    # allow inbound to openvpn
    add_rule sg_id, '17', 1194, 1194, '0.0.0.0/0'
    # allow ping
    add_rule sg_id, '1', -1, -1, '0.0.0.0/0'
    
    show(vpc, 'DMZ')
  end
  
  def create_mgz(vpc, dmz)
    # short-circuit if this already exists
    existing = show(vpc, 'MGZ')
    if existing
      logger.info "Security Group 'DMZ' already exists"
      return existing
    end
    
    # create the security group
    logger.info "Creating the Security Group 'DMZ'"
    sg = create_group(vpc, 'MGZ')
    
    # extract the ID for convenience 
    sg_id = sg['groupId']
    
    # tag the security group with a name
    logger.info "Tagging Security Group"
    tag_group(vpc, sg_id, 'MGZ')
    
    # create inbound rules
    # 
    logger.info "Adding ingress rules to MGZ"
    # allow anything from the dmz
    add_rule sg_id, '-1', -1, -1, dmz[:subnet]
    
    show(vpc, 'MGZ')
  end
  
  def create_apz(vpc, dmz, mgz, name)
    # short-circuit if this already exists
    existing = show(vpc, name)
    if existing
      logger.info "Security Group '#{name}' already exists"
      return existing
    end
    
    # create the security group
    logger.info "Creating the Security Group '#{name}'"
    sg = create_group(vpc, name)
    
    # extract the ID for convenience 
    sg_id = sg['groupId']
    
    # tag the security group with a name
    logger.info "Tagging Security Group"
    tag_group(vpc, sg_id, name)
    
    # create inbound rules
    # 
    logger.info "Adding ingress rules to '#{name}'"
    # allow anything from the dmz
    add_rule sg_id, '-1', -1, -1, dmz[:subnet]
    # allow anything from the mgz
    add_rule sg_id, '-1', -1, -1, mgz[:subnet]
    # allow http from anywhere
    add_rule sg_id, '6', 80, 80, '0.0.0.0/0'
    # allow https from anywhere
    add_rule sg_id, '6', 443, 443, '0.0.0.0/0'
    
    show(vpc, name)
  end
  
  protected
  
  def create_group(vpc, name)
    res = manager.CreateSecurityGroup(
      'GroupDescription'  => "Nanobox Unity #{vpc[:name]} Zone #{name}",
      'GroupName'         => "Nanobox-Unity-#{vpc[:name]}-#{name}",
      'VpcId'             => vpc[:id]
    )
    
    res['CreateSecurityGroupResponse']
  end
  
  def tag_group(vpc, group_id, name)
    # tag the acl
    res = manager.CreateTags(
      'ResourceId'  => group_id,
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
          'Key' => 'FirewallName',
          'Value' => name
        }
      ]
    )
  end
  
  def add_rule(sg_id, protocol, from, to, network)
    res = manager.AuthorizeSecurityGroupIngress(
      'GroupId'     => sg_id,
      'CidrIp'      => network,
      'IpProtocol'  => protocol,
      'FromPort'    => from,
      'ToPort'      => to
    )
    
    res['return']
  end
  
  def process(data)
    {
      id: data['groupId'],
      name: (process_tag(data['tagSet']['item'], 'FirewallName') rescue 'unknown'),
      ingress: (process_rules(data['ipPermissions']) rescue 'na'),
      egress: (process_rules(data['ipPermissionsEgress']) rescue 'na')
    }
  end
  
  def process_rules(entries)
    collection = begin
      if entries['item'].is_a? Array
        entries['item']
      else
        [entries['item']]
      end
    end
    
    collection.map do |entry|
      process_rule(entry)
    end
  end
  
  def process_rule(data)
    {
      protocol: data['ipProtocol'],
      from:     data['fromPort'],
      to:       data['toPort'],
      cidr:     (data['ipRanges']['item']['cidrIp'] rescue 'na')
    }
  end
  
end
