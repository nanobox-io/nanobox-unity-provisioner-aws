class Unity::EC2::Route < Unity::EC2::Base
  
  def add_vpc_to_gateway(vpc, gateway)
    
    table = fetch_route_table(vpc[:id])
    
    # add an internet accessible route
    logger.info "Adding internet accessable route for VPC '#{vpc[:name]}'"
    res = manager.CreateRoute(
      'RouteTableId'          => table['routeTableId'],
      'DestinationCidrBlock'  => '0.0.0.0/0',
      'GatewayId'             => gateway[:id]
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
