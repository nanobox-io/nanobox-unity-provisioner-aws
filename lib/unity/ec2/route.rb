class Unity::EC2::Route
  
  attr_reader :manager
  
  def initialize(manager)
    @manager = manager
  end
  
  def add_vpc_to_gateway(vpc_id, gateway_id)
    # https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_CreateRoute.html
    table = fetch_route_table(vpc_id)
    
    res = manager.CreateRoute(
      'RouteTableId'          => table['routeTableId'],
      'DestinationCidrBlock'  => '0.0.0.0/0',
      'GatewayId'             => gateway_id
    )
    
    res["CreateRouteResponse"]["return"]
  end
  
  protected
  
  def fetch_route_table(vpc_id)
    # filter the collection to just nanobox instances
    filter = [{'Name'  => 'vpc-id', 'Value' => vpc_id}]

    # query the api
    res = manager.DescribeRouteTables('Filter' => filter)

    # extract the instance collection
    tables = res["DescribeRouteTablesResponse"]["routeTableSet"]

    # short-circuit if the collection is empty
    return nil if tables.nil?

    # tables might not be a collection, but a single item
    collection = begin
      if tables['item'].is_a? Array
        tables['item']
      else
        [tables['item']]
      end
    end

    collection.first
  end
  
end
