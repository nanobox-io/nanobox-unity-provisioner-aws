class Unity::EC2::AvailabilityZone < Unity::EC2::Base
  
  def list
    list = []
    
    # filter the collection to just zones that are available
    filter = [
      {'Name' => 'state', 'Value' => 'available'}
    ]
    
    # query the api
    res = manager.DescribeAvailabilityZones('Filter' => filter)
    
    # extract the collection
    zones = res['DescribeAvailabilityZonesResponse']['availabilityZoneInfo']
    
    return [] if zones.nil?
    
    # zones might not be a collection, but a single item
    collection = begin
      if zones['item'].is_a? Array
        zones['item']
      else
        [zones['item']]
      end
    end
    
    # grab the zones and process them
    collection.each do |zone|
      list << process(zone)
    end

    list
  end
  
  protected
  
  def process(data)
    {
      name:   data['zoneName'],
      state:  data['zoneState'],
      region: data['regionName']
    }
  end

end
