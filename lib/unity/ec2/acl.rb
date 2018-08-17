class Unity::EC2::ACL < Unity::EC2::Base
  
  def list(vpc)
    list = []

    # filter the collection to just nanobox instances
    filter = [
      {'Name'  => 'vpc-id',       'Value' => vpc[:id]},
      {'Name'  => 'tag:Nanobox',  'Value' => 'true'}
    ]

    # query the api
    res = manager.DescribeNetworkAcls('Filter' => filter)

    # extract the instance collection
    acls = res["DescribeNetworkAclsResponse"]["networkAclSet"]

    # short-circuit if the collection is empty
    return [] if acls.nil?

    # acls might not be a collection, but a single item
    collection = begin
      if acls['item'].is_a? Array
        acls['item']
      else
        [acls['item']]
      end
    end

    # grab the vpcs and process them
    collection.each do |acl|
      list << process(acl)
    end

    list
  end
  
  def show(vpc, name)
    list(vpc).each do |acl|
      if acl[:name] == name
        return acl
      end
    end
    
    # return nil if we can't find it
    nil
  end
  
  def create_dmz(vpc)
    # short-circuit if this already exists
    existing = show(vpc, 'DMZ')
    if existing
      logger.info "ACL 'DMZ' already exists"
      return existing
    end
    
    # create the acl
    logger.info "Creating ACL 'DMZ'"
    acl = create_acl(vpc[:id])
    
    # extract the ID for convenience
    acl_id = acl['networkAclId']
    
    # tag the acl with a name
    logger.info "Tagging ACL"
    tag_acl(vpc, acl_id, 'DMZ')
    
    # create inbound rules
    # 
    logger.info "Adding ingress rules to DMZ"
    # allow all inbound traffic
    add_rule acl_id, :ingress, 200, '-1', 1, 65535, '0.0.0.0/0', 'allow'
    # 
    # create outbound rules
    # 
    logger.info "Adding egress rules to DMZ"
    # allow all outbound traffic
    add_rule acl_id, :egress, 200, '-1', 1, 65535, '0.0.0.0/0', 'allow'
    
    show(vpc, 'DMZ')
  end
  
  def create_mgz(vpc, dmz)
    # short-circuit if this already exists
    existing = show(vpc, 'MGZ')
    if existing
      logger.info "ACL 'MGZ' already exists"
      return existing
    end
    
    # create the acl
    logger.info "Creating ACL 'MGZ'"
    acl = create_acl(vpc[:id])
    
    # extract the ID for convenience
    acl_id = acl['networkAclId']
    
    # tag the acl with a name
    logger.info "Tagging ACL"
    tag_acl(vpc, acl_id, 'MGZ')
    
    # create inbound rules
    # 
    logger.info "Adding ingress rules to DMZ"
    # allow all inbound traffic
    add_rule acl_id, :ingress, 200, '-1', 1, 65535, '0.0.0.0/0', 'allow'
    # 
    # create outbound rules
    # 
    logger.info "Adding egress rules to DMZ"
    # allow all outbound traffic
    add_rule acl_id, :egress, 200, '-1', 1, 65535, '0.0.0.0/0', 'allow'
    
    show(vpc, 'MGZ')
  end
  
  def create_apz(vpc, dmz, mgz)
    # short-circuit if this already exists
    existing = show(vpc, "APZ")
    if existing
      logger.info "ACL 'APZ' already exists"
      return existing
    end
    
    # create the acl
    logger.info "Creating ACL 'APZ'"
    acl = create_acl(vpc[:id])
    
    # extract the ID for convenience
    acl_id = acl['networkAclId']
    
    # tag the acl with a name
    logger.info "Tagging ACL"
    tag_acl(vpc, acl_id, "APZ")
    
    # create inbound rules
    # 
    logger.info "Adding ingress rules to DMZ"
    # allow all inbound traffic
    add_rule acl_id, :ingress, 200, '-1', 1, 65535, '0.0.0.0/0', 'allow'
    # 
    # create outbound rules
    # 
    logger.info "Adding egress rules to DMZ"
    # allow all outbound traffic
    add_rule acl_id, :egress, 200, '-1', 1, 65535, '0.0.0.0/0', 'allow'
    
    show(vpc, "APZ")
  end
  
  def attach_subnet(acl, subnet)
    acl_id    = acl[   :id]
    subnet_id = subnet[:id]
    
    logger.info "Attaching subnet '#{subnet[:name]}' to ACL '#{acl[:name]}'"
    
    # find the current association
    # filter the collection to just nanobox instances
    filter = [{'Name'  => 'association.subnet-id', 'Value' => subnet_id}]

    # query the api
    res = manager.DescribeNetworkAcls('Filter' => filter)
    
    # grab the current association
    associations = res["DescribeNetworkAclsResponse"]["networkAclSet"]['item']['associationSet']['item']
    
    if not associations.is_a? Array
      associations = [associations]
    end
    
    # grab the association out of the list
    association_id = ''
    
    associations.each do |assoc|
      if assoc['subnetId'] == subnet_id
        association_id = assoc['networkAclAssociationId']
      end
    end
    
    # update the association
    res = manager.ReplaceNetworkAclAssociation(
      'AssociationId' => association_id,
      'NetworkAclId'  => acl_id
    )
  end
  
  protected
  
  def create_acl(vpc_id)
    res = manager.CreateNetworkAcl(
      'VpcId' => vpc_id
    )
    
    res['CreateNetworkAclResponse']['networkAcl']
  end
  
  def tag_acl(vpc, acl_id, name)
    # tag the acl
    res = manager.CreateTags(
      'ResourceId'  => acl_id,
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
  
  def add_rule(acl_id, direction, number, protocol, from, to, network, action)
    # create the rule
    res = manager.CreateNetworkAclEntry(
      'NetworkAclId'    => acl_id,
      'Egress'          => (direction == :egress),
      'RuleNumber'      => number,
      'Protocol'        => protocol,
      'PortRange.From'  => from,
      'PortRange.To'    => to,
      'CidrBlock'       => network,
      'RuleAction'      => action
    )
    
    res['CreateNetworkAclEntryResponse']['return']
  end
  
  def process(data)
    {
      id:       data["networkAclId"],
      name:     (process_tag(data['tagSet']['item'], 'FirewallName') rescue 'unknown'),
      ingress:  process_rules(data['entrySet'], :ingress),
      egress:   process_rules(data['entrySet'], :egress)
    }
  end
  
  def process_rules(entries, direction)
    collection = begin
      if entries['item'].is_a? Array
        entries['item']
      else
        [entries['item']]
      end
    end
    
    # remove the irrelevant rules
    collection.delete_if do |entry|
      case direction
      when :ingress
        entry['egress'] == false
      when :egress
        entry['egress'] == true
      end
    end
    
    collection.map do |entry|
      process_rule(entry)
    end
  end
  
  def process_rule(data)
    {
      number:   data['ruleNumber'],
      protocol: data['protocol'],
      action:   data['ruleAction'],
      cidr:     data['cidrBlock']
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
