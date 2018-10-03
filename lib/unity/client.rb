require 'right_aws_api'

class Unity::Client

  attr_reader :key_id
  attr_reader :access_key
  attr_reader :endpoint

  def initialize(key_id, access_key, endpoint, logger=nil)
    @key_id     = key_id
    @access_key = access_key
    @endpoint   = endpoint
    @logger     = logger
  end

  def verify
    # need to ensure we can run all of the necessary actions
    # (these will raise an error if they don't have permissions)
    # ::EC2::SSH.new(manager).permission?
  end
  
  def envs
    Unity::EC2::VPC.new(ec2_manager, logger).list
  end
  
  def env(name)
    Unity::EC2::VPC.new(ec2_manager, logger).show(name)
  end
  
  def create_env(name)
    # create the adapters
    vpc_adapter     = Unity::EC2::VPC.new(ec2_manager, logger)
    gateway_adapter = Unity::EC2::Gateway.new(ec2_manager, logger)
    subnet_adapter  = Unity::EC2::Subnet.new(ec2_manager, logger)
    acl_adapter     = Unity::EC2::ACL.new(ec2_manager, logger)
    sg_adapter      = Unity::EC2::SecurityGroup.new(ec2_manager, logger)
    route_adapter   = Unity::EC2::Route.new(ec2_manager, logger)
    zone_adapter    = Unity::EC2::AvailabilityZone.new(ec2_manager, logger)
    
    # create vpc
    vpc = vpc_adapter.create(name)
    
    # create internet gateway
    gateway = gateway_adapter.create(name)
    
    # attach gateway to the vpc
    gateway_adapter.attach(vpc, gateway)
    
    # add vpc route table to internet gateway
    route_adapter.add_vpc_to_gateway(vpc, gateway)
    
    # create DMZ acl
    dmz_acl = acl_adapter.create_dmz(vpc)
    
    # create MGZ acl
    mgz_acl = acl_adapter.create_mgz(vpc)
    
    # create the APZ acl
    apz_acl = acl_adapter.create_apz(vpc)
    
    # collect the availability zones
    zones = zone_adapter.list
    
    # create DMZ subnets
    dmzs = subnet_adapter.create(vpc, 'DMZ', zones)
    
    # create MGZ subnets
    mgzs = subnet_adapter.create(vpc, 'MGZ', zones)
    
    # create the DMZ security group
    dmz_sg = sg_adapter.create_dmz(vpc)
    
    # create the MGZ security group
    mgz_sg = sg_adapter.create_mgz(vpc, dmzs, mgzs)
    
    # attach DMZ acl to DMZ
    acl_adapter.attach_subnets(dmz_acl, dmzs)
    
    # attach MGZ acl to DMZ
    acl_adapter.attach_subnets(mgz_acl, mgzs)
    
    # return the vpc
    vpc
  end
  
  def zones(env_name)
    # find the vpc
    vpc = Unity::EC2::VPC.new(ec2_manager, logger).show(env_name)
    
    if vpc.nil?
      return nil
    end
    
    Unity::EC2::Subnet.new(ec2_manager, logger).list(vpc)
  end
  
  def zone(env_name, zone_name)
    vpc = Unity::EC2::VPC.new(ec2_manager, logger).show(env_name)
    
    Unity::EC2::Subnet.new(ec2_manager, logger).show(vpc, zone_name)
  end
  
  def create_zone(env_name, zone_name)
    # create the adapters
    vpc_adapter    = Unity::EC2::VPC.new(ec2_manager, logger)
    subnet_adapter = Unity::EC2::Subnet.new(ec2_manager, logger)
    acl_adapter    = Unity::EC2::ACL.new(ec2_manager, logger)
    policy_adapter = Unity::IAM::Policy.new(iam_manager, logger)
    sg_adapter     = Unity::EC2::SecurityGroup.new(ec2_manager, logger)
    zone_adapter   = Unity::EC2::AvailabilityZone.new(ec2_manager, logger)
    
    # load vpc
    vpc = vpc_adapter.show(env_name)
    
    if vpc.nil?
      return nil
    end
    
    # collect the availability zones
    zones = zone_adapter.list
    
    # create subnets
    apzs = subnet_adapter.create(vpc, "APZ-#{zone_name}", zones)
    
    # load the dmz subnets
    dmzs = subnet_adapter.show_all(vpc, 'DMZ')
    
    # load the mgz subnets
    mgzs = subnet_adapter.show_all(vpc, 'MGZ')
    
    # create security group
    sg = sg_adapter.create_apz(vpc, dmzs, mgzs, apzs, "APZ-#{zone_name}")
    
    # load the APZ acl
    acl = acl_adapter.show(vpc, 'APZ')
    
    # attach APZ acl
    acl_adapter.attach_subnets(acl, apzs)
    
    apzs
  end
    
  protected

  def logger
    @logger ||= begin
      ::Unity::Logger::Stdout.new
    end
  end

  def ec2_manager
    @ec2_manager ||= begin
      ::RightScale::CloudApi::AWS::EC2::Manager.new(key_id, access_key, endpoint_uri, :api_version => "2016-11-15")
    end
  end
  
  def iam_manager
    @iam_manager ||= begin
      ::RightScale::CloudApi::AWS::IAM::Manager.new(key_id, access_key, 'https://iam.amazonaws.com', :api_version => "2010-05-08")
    end
  end

  def endpoint_uri
    "https://ec2.#{endpoint}.amazonaws.com"
  end

end
