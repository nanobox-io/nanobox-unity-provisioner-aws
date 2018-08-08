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
    Unity::EC2::VPC.new(ec2_manager).list
  end
  
  def env(name)
    Unity::EC2::VPC.new(ec2_manager).show(name)
  end
  
  def create_env(name)
    # create the adapters
    vpc_adapter     = Unity::EC2::VPC.new(ec2_manager, logger)
    gateway_adapter = Unity::EC2::Gateway.new(ec2_manager, logger)
    subnet_adapter  = Unity::EC2::Subnet.new(ec2_manager, logger)
    acl_adapter     = Unity::EC2::ACL.new(ec2_manager, logger)
    route_adapter   = Unity::EC2::Route.new(ec2_manager, logger)
    
    # create vpc
    vpc = vpc_adapter.create(name)
    
    # create internet gateway
    gateway = gateway_adapter.create(name)
    
    # attach gateway to the vpc
    gateway_adapter.attach(vpc, gateway)
    
    # add vpc route table to internet gateway
    route_adapter.add_vpc_to_gateway(vpc, gateway)
    
    # create DMZ subnet
    dmz = subnet_adapter.create(vpc, 'DMZ')
    
    # create MGZ subnet
    mgz = subnet_adapter.create(vpc, 'MGZ')
    
    # create DMZ acl
    dmz_acl = acl_adapter.create_dmz(vpc)
    
    # create MGZ acl
    mgz_acl = acl_adapter.create_mgz(vpc, dmz)
    
    # create the APZ acl
    apz_acl = acl_adapter.create_apz(vpc, dmz, mgz)
    
    # attach DMZ acl to DMZ
    acl_adapter.attach_subnet(dmz_acl, dmz)
    
    # attach MGZ acl to DMZ
    acl_adapter.attach_subnet(mgz_acl, mgz)
    
    # return the vpc
    vpc
  end
  
  def zones(env_name)
  end
  
  def zone(env_name, zone_name)
  end
  
  def create_zone(env_name, zone_name)
    # load vpc
    
    # create subnet
    
    # load dmz
    
    # load mgz
    
    # create APZ acl
    
    # attach APZ acl
    
    # create IAM profile
    
    # create IAM user
  end
    
  protected

  def logger
    @logger ||= begin
      ::Unity::Logger::Stdout.new
    end
  end

  def ec2_manager
    @manager ||= begin
      ::RightScale::CloudApi::AWS::EC2::Manager.new(key_id, access_key, endpoint_uri, :api_version => "2016-11-15")
    end
  end

  def endpoint_uri
    "https://ec2.#{endpoint}.amazonaws.com"
  end

end
